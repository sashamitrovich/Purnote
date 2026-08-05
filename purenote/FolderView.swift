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

    /// The folder currently being renamed, identified by URL rather than by
    /// index or name: the index shifts when the list changes underneath us,
    /// and the name changes on every keystroke while renaming.
    @State private var renamingFolder: URL?
    @State private var draftName = ""
    @State private var folderPendingDelete: URL?
    @FocusState private var renameFieldFocused: Bool

    @ViewBuilder
    var body: some View {

        ForEach(data.folders) { folder in
            if renamingFolder == folder.url {
                renameRow(folder)
            } else {
                folderRow(folder)
            }
        }
        .listStyle(PlainListStyle())

        if data.folders.isEmpty {
            VStack {
                HStack {
                    Text("Tap the")
                    Image(systemName: "folder.badge.plus")
                    Text("button to create a new folder")
                }.placeholderForegroundColor()
            }
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        NavigationLink {
            FolderDestination(url: folder.url)
        } label: {
            HStack {
                Image(systemName: "folder")
                    // my own modest Image extension
                    // inspired by
                    // https://stackoverflow.com/a/59974025/1393362
                    .systemOrange()
                Text(folder.id)
                    .fontWeight(.semibold)
                    .font(.title3)
                    .foregroundColor(Color(UIColor.label))
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
            Text("The folder is moved to the Trash")
        }
    }

    private func renameRow(_ folder: Folder) -> some View {
        HStack {
            Image(systemName: "folder")
                .systemOrange()

            TextField(folder.id, text: $draftName)
                .font(.title3)
                .focused($renameFieldFocused)
                .submitLabel(.done)
                .onSubmit { commitRename(of: folder) }

            Spacer()

            Button {
                cancelRename()
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .onAppear { renameFieldFocused = true }
    }

    // MARK: - Deleting

    private func deleteConfirmation(for folder: Folder) -> Binding<Bool> {
        Binding(
            get: { folderPendingDelete == folder.url },
            set: { if !$0 { folderPendingDelete = nil } }
        )
    }

    private func deleteFolder(_ folder: Folder) {
        do {
            try CoordinatedFile.trash(folder.url)
        }
        catch {
            // failed
            print("Failed to delete directory: \(error).")
            return
        }
        data.folders.removeAll { $0.url == folder.url }
    }

    // MARK: - Renaming

    private func commitRename(of folder: Folder) {
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

    init(url: URL) {
        _data = StateObject(wrappedValue: DataManager(url: url))
    }

    var body: some View {
        MenuView().environmentObject(data)
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            FolderView().environmentObject(DataManager.sampleDataManager())
        }
    }
}
