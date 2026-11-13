//
//  FolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import UIKit

struct FolderView: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @EnvironmentObject var toast: UndoToastModel

    /// The folder currently being renamed, identified by URL rather than by
    /// index or name: the index shifts when the list changes underneath us,
    /// and the name changes on every keystroke while renaming.
    @State private var renamingFolder: URL?
    @State private var draftName = ""
    @State private var folderPendingDelete: URL?
    @State private var dropTargetedFolder: URL?
    @AppStorage("useLocalStorage") private var useLocalStorage = false

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Two columns, like the index of a book. At the accessibility text sizes
    /// two columns would cut every name short, so it becomes one.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 24, alignment: .leading), GridItem(.flexible(), alignment: .leading)]
    }

    @ViewBuilder
    var body: some View {

        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(data.folders) { folder in
                folderRow(folder)
            }
        }
        .alert("Rename Folder", isPresented: renameAlertPresented) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) { cancelRename() }
            Button("Save") { commitRename() }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(NotesLocation.current(useLocalStorage: useLocalStorage).renameMessage)
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        NavigationLink {
            FolderDestination(url: folder.url, libraryRoot: index.rootUrl)
        } label: {
            HStack(spacing: 8) {
                Text(folder.id)
                    .font(PurnoteType.Twin.ui())
                    .foregroundColor(Color.pn.ink)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // how many notes are inside, the way Notes shows it
                Text("\(noteCount(in: folder))")
                    .font(PurnoteType.Twin.meta())
                    .foregroundColor(Color.pn.ink2)
                    .monospacedDigit()
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .menuRowStyle()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(dropTargetedFolder == folder.url
                          ? Color.pn.ribbon.opacity(0.15)
                          : Color.clear)
            )
            .dropDestination(for: String.self) { paths, _ in
                guard let path = paths.first,
                      let note = data.notes.first(where: { $0.url.path == path }) else {
                    return false
                }
                data.move(note: note, to: folder.url)
                index.indexall()
                return true
            } isTargeted: { targeted in
                dropTargetedFolder = targeted ? folder.url
                    : (dropTargetedFolder == folder.url ? nil : dropTargetedFolder)
            }
        }
        .contextMenu {
            Button {
                draftName = folder.id
                renamingFolder = folder.url
            } label: {
                Text("Rename Folder")
                Image(systemName: "pencil")
            }

            Button(role: .destructive) {
                folderPendingDelete = folder.url
            } label: {
                Text("Delete Folder")
                Image(systemName: "trash")
            }
        }
        // scoped to this row's url, so only the folder actually being deleted
        // puts up an alert
        .alert("Are you sure you want to delete \(folder.id) and its contents?",
               isPresented: deleteConfirmation(for: folder)) {
            Button("Delete", role: .destructive) { deleteFolder(folder) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The folder and the notes in it move to Recently Deleted.")
        }
    }

    /// The number of notes directly inside a folder. Counts the `.md` files,
    /// including any still showing as iCloud `.icloud` placeholders, and
    /// ignores nested folders.
    private func noteCount(in folder: Folder) -> Int {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder.url,
            includingPropertiesForKeys: [.isDirectoryKey])) ?? []

        return contents.filter { url in
            !url.hasDirectoryPath && url.lastPathComponent.contains(".md")
        }.count
    }

    // MARK: - Deleting

    private func deleteConfirmation(for folder: Folder) -> Binding<Bool> {
        Binding(
            get: { folderPendingDelete == folder.url },
            set: { if !$0 { folderPendingDelete = nil } }
        )
    }

    /// Moves the folder and its notes to Recently Deleted. The row goes and the
    /// Undo toast comes up; if the move fails the row stays and an alert says why.
    private func deleteFolder(_ folder: Folder) {
        toast.delete(folder: folder, from: data, index: index)
    }

    // MARK: - Renaming

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { cancelRename() } }
        )
    }

    private func commitRename() {
        guard let url = renamingFolder,
              let folder = data.folders.first(where: { $0.url == url }) else {
            cancelRename()
            return
        }

        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { cancelRename() }

        guard !newName.isEmpty, newName != folder.id else { return }

        let newUrl = folder.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try CoordinatedFile.move(from: folder.url, to: newUrl)
        }
        catch {
            // failed
            print("Failed to rename directory: \(error).")
            return
        }

        data.pinsFollowMove(from: folder.url, to: newUrl)

        // the url has to move with the name, otherwise the row still points at
        // the old path and navigating into it finds nothing
        if let index = data.folders.firstIndex(where: { $0.url == folder.url }) {
            data.folders[index].id = newName
            data.folders[index].url = newUrl
        }
    }

    private func cancelRename() {
        renamingFolder = nil
        draftName = ""
    }
}

/// Builds the folder's DataManager lazily, in `body` rather than where the
/// NavigationLink is created — otherwise every visible row lists its directory
/// off disk just to render the link.
private struct FolderDestination: View {
    @StateObject private var data: DataManager

    init(url: URL, libraryRoot: URL) {
        _data = StateObject(wrappedValue: DataManager(url: url, libraryRoot: libraryRoot))
    }

    var body: some View {
        MenuView().environmentObject(data)
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            FolderView().environmentObject(DataManager.sampleDataManager())
                .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "/notes")))
                .environmentObject(UndoToastModel())
        }
    }
}
