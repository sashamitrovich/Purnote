//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI

/// The notes of the folder on screen, drawn from a HomeListModel: a Pinned
/// section (root only), then month groups with the day in the margin, or one
/// plain list when sorted by title.
struct NotesList: View {
    let model: HomeListModel
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @EnvironmentObject var toast: UndoToastModel
    @State private var noteToMove: Note?

    /// Moves the note to Recently Deleted. The row goes and the Undo toast comes
    /// up; if the move fails the row stays and an alert says why.
    func delete(_ note: Note) {
        toast.delete(note: note, from: data, index: index)
    }

    var body: some View {
        ForEach(model.sections) { section in
            if let title = section.title {
                HomeSectionHeader(title: title,
                                  identifier: section.kind == .pinned ? "home.pinnedSection" : "home.monthHeader")
            }
            ForEach(section.entries) { entry in
                row(entry)
            }
        }
        .sheet(item: $noteToMove) { note in
            MoveNoteSheet(note: note)
                .environmentObject(data)
                .environmentObject(index)
        }
    }

    @ViewBuilder
    private func row(_ entry: HomeListModel.Entry) -> some View {
        let note = entry.note
        if note.isLocal {
            NavigationLink(destination: NoteDestination(note: note, screenData: data, libraryRoot: index.rootUrl)
                            .environmentObject(index)) {
                HomeNoteRow(entry: entry)
            }
            .accessibilityValue(accessibilityValue(for: entry))
            .contextMenu {
                Button {
                    data.togglePin(note)
                } label: {
                    Label(data.isPinned(note) ? "Unpin Note" : "Pin Note",
                          systemImage: data.isPinned(note) ? "pin.slash" : "pin")
                }
                Button {
                    noteToMove = note
                } label: {
                    Text("Move Note")
                    Image(systemName: "folder")
                }
                Button(role: .destructive) {
                    delete(note)
                } label: {
                    Text("Delete Note")
                    Image(systemName: "trash")
                }
            }
            .draggable(note.url.path)
            .menuRowStyle()
        } else {
            ICloudItemView(note: note)
                .environmentObject(data)
                .environmentObject(index)
                .frame(maxWidth: .infinity, alignment: .leading)
                .menuRowStyle()
        }
    }

    /// What the margin says to VoiceOver, which skips the margin itself.
    private func accessibilityValue(for entry: HomeListModel.Entry) -> String {
        let date = NoteRowText.relativeDate(entry.note.date)
        return entry.margin == .ribbon ? "Pinned, \(date)" : date
    }
}

/// A note opens with the DataManager of the folder it lives in. A pinned note
/// from another folder, shown at the root, must not be edited through the
/// root's DataManager: saving would add it to the root's list.
private struct NoteDestination: View {
    let note: Note
    let screenData: DataManager
    let libraryRoot: URL
    @EnvironmentObject var index: SearchIndex

    var body: some View {
        if note.url.deletingLastPathComponent().standardizedFileURL.path
            == screenData.getCurrentUrl().standardizedFileURL.path {
            NoteView(note: note).environmentObject(screenData).environmentObject(index)
        } else {
            FolderNote(note: note, libraryRoot: libraryRoot)
        }
    }
}

private struct FolderNote: View {
    let note: Note
    @StateObject private var folderData: DataManager
    @EnvironmentObject var index: SearchIndex

    init(note: Note, libraryRoot: URL) {
        self.note = note
        _folderData = StateObject(wrappedValue: DataManager(url: note.url.deletingLastPathComponent(),
                                                            libraryRoot: libraryRoot))
    }

    var body: some View {
        NoteView(note: note).environmentObject(folderData).environmentObject(index)
    }
}
