//
//  MoveNoteSheet.swift
//  purenote
//

import SwiftUI

/// In-app "Move Note" destination picker: Purnote's own folder tree, not the
/// system Files picker. Drill into a folder to move into it, or move to the
/// level itself.
struct MoveNoteSheet: View {
    let note: Note
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @Environment(\.dismiss) private var dismiss

    private var allFolders: [String] { SharedInbox.folders(in: index.rootUrl) }

    var body: some View {
        NavigationStack {
            MoveFolderLevel(path: "", allFolders: allFolders) { destination in
                if let destination {
                    moveNote(to: destination)
                } else {
                    dismiss()
                }
            }
        }
    }

    private func moveNote(to destination: String) {
        let root = index.rootUrl
        let targetDirectory = destination.isEmpty ? root : root.appendingPathComponent(destination)
        let newURL = targetDirectory.appendingPathComponent(note.id)
        guard newURL != note.url else { dismiss(); return }

        do {
            try CoordinatedFile.move(from: note.url, to: newURL)
            try NoteAssets.moveAssetsFolder(forNoteAt: note.url, to: newURL)
        } catch {
            print("Failed to move note: \(error).")
        }
        data.refresh(url: data.getCurrentUrl())
        index.indexall()
        dismiss()
    }
}

/// One level of the move picker: "move here" plus the subfolders to drill into.
private struct MoveFolderLevel: View {
    let path: String
    let allFolders: [String]
    let onPick: (String?) -> Void

    private var subfolders: [String] { SharedInbox.childFolders(of: path, in: allFolders) }

    var body: some View {
        List {
            Button {
                onPick(path)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: path.isEmpty ? "note.text" : "folder")
                        .accent()
                    Text(path.isEmpty ? "Notes" : "Move to \((path as NSString).lastPathComponent)")
                        .foregroundColor(Color(UIColor.label))
                }
            }

            ForEach(subfolders, id: \.self) { folder in
                NavigationLink {
                    MoveFolderLevel(path: folder, allFolders: allFolders, onPick: onPick)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .accent()
                        Text((folder as NSString).lastPathComponent)
                            .foregroundColor(Color(UIColor.label))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.purnotePaper)
        .navigationTitle(path.isEmpty ? "Move Note" : (path as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if path.isEmpty {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onPick(nil) }
                }
            }
        }
    }
}
