//
//  SmartFolderList.swift
//  purenote
//

import SwiftUI

/// Holds the user's smart folders in memory and persists them to the
/// `.purnote/smartfolders.json` sidecar. The notes themselves are never
/// touched.
final class SmartFolderList: ObservableObject {
    @Published var folders: [SmartFolder]
    private let rootUrl: URL

    init(rootUrl: URL) {
        self.rootUrl = rootUrl
        self.folders = SmartFolderStore.load(from: rootUrl)
    }

    func add(name: String, tags: [String]) {
        folders.append(SmartFolder(name: name, tags: tags))
        persist()
    }

    func update(_ folder: SmartFolder, name: String, tags: [String]) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
        folders[index].tags = tags
        persist()
    }

    func remove(_ folder: SmartFolder) {
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    private func persist() {
        try? SmartFolderStore.save(folders, to: rootUrl)
    }
}

/// The smart-folder rows, listed at the top of the Folders section. A smart
/// folder is a saved filter, not a real directory, so it gets a tray icon
/// rather than the folder icon real folders use. Only ever shown at the root,
/// and only when at least one smart folder exists — creating one happens from
/// the bottom bar's new-folder menu, not from the list.
struct SmartFoldersView: View {
    @EnvironmentObject var folders: SmartFolderList
    @EnvironmentObject var index: SearchIndex
    @State private var editingFolder: SmartFolder?

    var body: some View {
        ForEach(folders.folders) { folder in
            NavigationLink(destination: SmartFolderDestination(folder: folder)) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.full")
                        .systemOrange()
                    Text(folder.name)
                        .font(.title3)
                        .foregroundColor(Color(UIColor.label))
                        .lineLimit(1)
                    Spacer()
                    Text("\(index.searchByTags(folder.tags).count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .contextMenu {
                Button {
                    editingFolder = folder
                } label: {
                    Text("Edit Smart Folder")
                    Image(systemName: "pencil")
                }
                Button(role: .destructive) {
                    folders.remove(folder)
                } label: {
                    Text("Delete Smart Folder")
                    Image(systemName: "trash")
                }
            }
            .menuRowStyle()
        }
        .sheet(item: $editingFolder) { folder in
            SmartFolderEditor(folders: folders, index: index, folder: folder)
        }
    }
}

/// The notes matching a smart folder's tags.
struct SmartFolderDestination: View {
    let folder: SmartFolder
    @EnvironmentObject var index: SearchIndex

    var body: some View {
        FilteredNotesView(notes: index.searchByTags(folder.tags))
            .navigationTitle(folder.name)
    }
}

/// Create or edit a smart folder: a name plus a set of tags, chosen from the
/// tags already present in the library.
struct SmartFolderEditor: View {
    @ObservedObject var folders: SmartFolderList
    let index: SearchIndex
    let folder: SmartFolder?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedTags: Set<String>

    init(folders: SmartFolderList, index: SearchIndex, folder: SmartFolder? = nil) {
        self.folders = folders
        self.index = index
        self.folder = folder
        _name = State(initialValue: folder?.name ?? "")
        _selectedTags = State(initialValue: Set(folder?.tags ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                Section("Tags") {
                    let tags = index.allTags()
                    if tags.isEmpty {
                        Text("Type a #tag in any note and it will appear here.")
                            .foregroundColor(Color(UIColor.placeholderText))
                    } else {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Text("#\(tag)")
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color(UIColor.systemOrange))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(folder == nil ? "New Smart Folder" : "Edit Smart Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tags = selectedTags.sorted()
        if let folder {
            folders.update(folder, name: trimmed, tags: tags)
        } else {
            folders.add(name: trimmed, tags: tags)
        }
        dismiss()
    }
}
