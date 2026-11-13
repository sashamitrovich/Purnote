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
    /// A move that did not happen, said here; the sheet stays up.
    @State private var alert: TrashAlert?

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
        .alert(alert?.title ?? "",
               isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alert?.message ?? "")
        }
    }

    private func moveNote(to destination: String) {
        let root = index.rootUrl
        let targetDirectory = destination.isEmpty ? root : root.appendingPathComponent(destination)
        let newURL = targetDirectory.appendingPathComponent(note.id)
        guard newURL != note.url else { dismiss(); return }

        let failure = data.move(note: note, to: targetDirectory)
        index.indexall()
        if let failure { alert = failure } else { dismiss() }
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
                        .foregroundColor(Color.pn.ink)
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
                            .foregroundColor(Color.pn.ink)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.pn.page)
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
