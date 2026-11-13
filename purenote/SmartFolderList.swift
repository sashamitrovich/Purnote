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

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Two columns, like the index of a book. At the accessibility text sizes
    /// two columns would cut every name short, so it becomes one.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 24, alignment: .leading), GridItem(.flexible(), alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(folders.folders) { folder in
                NavigationLink(destination: SmartFolderDestination(folder: folder)) {
                    HStack(spacing: 8) {
                        // the tray keeps smart folders distinct from real ones
                        Image(systemName: "tray.full")
                            .font(.footnote)
                            .foregroundColor(Color.pn.ink2)
                        Text(folder.name)
                            .font(PurnoteType.Twin.ui())
                            .foregroundColor(Color.pn.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(index.searchByTags(folder.tags).count)")
                            .font(PurnoteType.Twin.meta())
                            .foregroundColor(Color.pn.ink2)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .menuRowStyle()
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
            }
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

    private var matchingNotes: [Note] {
        selectedTags.isEmpty ? [] : index.searchByTags(selectedTags.sorted())
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(PurnoteType.Twin.caps())
            .tracking(PurnoteType.capsTracking)
            .foregroundColor(Color.pn.ink2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        kicker("Name")
                        TextField("Name", text: $name)
                            .font(PurnoteType.Twin.masthead(long: true))
                            .foregroundColor(Color.pn.ink)
                            .tint(Color.pn.ribbon)
                        Rectangle().fill(Color.pn.rule).frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        kicker("Tags")
                        let tags = index.allTags()
                        if tags.isEmpty {
                            Text("Type a #tag in any note and it will appear here.")
                                .font(PurnoteType.Twin.ui())
                                .foregroundColor(Color.pn.ink2)
                        } else {
                            SmartFolderFlow(spacing: 10) {
                                ForEach(tags, id: \.self) { tag in
                                    tagChip(tag)
                                }
                            }
                        }
                    }

                    if !selectedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            kicker(matchingNotes.count == 1 ? "1 note matches" : "\(matchingNotes.count) notes match")
                            if !matchingNotes.isEmpty {
                                Text(matchingNotes.prefix(8)
                                        .map { $0.url.deletingPathExtension().lastPathComponent }
                                        .joined(separator: " \u{00B7} "))
                                    .font(PurnoteType.Twin.rowPreview())
                                    .foregroundColor(Color.pn.ink2)
                            }
                        }
                    }

                    Text("A smart folder is a saved search. It is stored in .purnote/smartfolders.json; no note is changed.")
                        .font(PurnoteType.Twin.meta())
                        .foregroundColor(Color.pn.ink2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pn.page)
            .navigationTitle(folder == nil ? "New Smart Folder" : "Edit Smart Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(PurnoteType.Twin.ui(weight: .semibold))
                            .foregroundColor(Color.pn.ink)
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    let canSave = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button { save() } label: {
                        Image(systemName: "checkmark")
                            .font(PurnoteType.Twin.ui(weight: .semibold))
                            .foregroundColor(canSave ? Color.white : Color.pn.ink3)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(canSave ? Color.pn.ribbon : Color.pn.fill)
                    .accessibilityLabel("Save")
                    .disabled(!canSave)
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let on = selectedTags.contains(tag)
        return Button {
            if on {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            HStack(spacing: 1) {
                Text("#").foregroundColor(on ? Color.pn.page.opacity(0.7) : Color.pn.ink3)
                Text(tag).foregroundColor(on ? Color.pn.page : Color.pn.ink2)
            }
            .font(PurnoteType.Twin.ui())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(on ? Color.pn.ink : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : Color.pn.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("#\(tag)")
        .accessibilityAddTraits(on ? .isSelected : [])
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

/// Lays its children out left to right and wraps to a new line when a row is
/// full. Used for the tag chips.
struct SmartFolderFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
