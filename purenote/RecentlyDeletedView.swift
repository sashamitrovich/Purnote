//
//  RecentlyDeletedView.swift
//  purenote
//
//  The screen behind "Recently Deleted" in the home screen's "..." menu. Every
//  deleted note and folder is kept here until the user deletes it here.
//

import SwiftUI

struct RecentlyDeletedView: View {
    @StateObject private var model: RecentlyDeletedModel
    @State private var rowPendingDelete: RecentlyDeletedModel.Row?
    @Environment(\.dynamicTypeSize) private var typeSize
    // 21 pt at the default size; follows Dynamic Type as .title2 does
    @ScaledMetric(relativeTo: .title2) private var emptyTitleSize: CGFloat = 21
    // 15 pt at the default size; follows Dynamic Type as .subheadline does
    @ScaledMetric(relativeTo: .subheadline) private var detailSize: CGFloat = 15

    init(root: URL, data: DataManager, index: SearchIndex) {
        _model = StateObject(wrappedValue: RecentlyDeletedModel(backend: .live(root: root, data: data, index: index)))
    }

    private var keptText: some View {
        Text("Kept until you delete them here.")
            .font(.footnote)
            .foregroundColor(Color.pn.ink2)
    }

    var body: some View {
        Group {
            if !model.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.rows.isEmpty {
                VStack(spacing: 6) {
                    Text("Nothing deleted.")
                        .font(.system(size: emptyTitleSize, weight: .semibold, design: .serif))
                        .foregroundColor(Color.pn.ink)
                        .accessibilityAddTraits(.isHeader)
                    keptText
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .background(Color.pn.page)
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete All", role: .destructive) { model.requestDeleteAll() }
                    .disabled(model.rows.isEmpty)
                    .accessibilityIdentifier("recentlyDeleted.deleteAll")
            }
        }
        .task { await model.load() }
        .confirmationDialog(deleteAllTitle,
                            isPresented: Binding(get: { model.deleteAllCandidates != nil },
                                                 set: { if !$0 { model.cancelDeleteAll() } }),
                            titleVisibility: .visible) {
            Button(deleteAllButton, role: .destructive) { Task { await model.confirmDeleteAll() } }
            Button("Cancel", role: .cancel) { model.cancelDeleteAll() }
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog("Delete \u{201C}\(rowPendingDelete?.title ?? "")\u{201D} for good?",
                            isPresented: Binding(get: { rowPendingDelete != nil },
                                                 set: { if !$0 { rowPendingDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: rowPendingDelete) { row in
            Button("Delete Forever", role: .destructive) { Task { await model.deleteForever(row) } }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This cannot be undone.")
        }
        .alert(model.alert?.title ?? "",
               isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.alert?.message ?? "")
        }
    }

    private var deleteAllTitle: String {
        let n = model.deleteAllCandidates?.count ?? 0
        return n == 1 ? "Delete 1 item for good?" : "Delete all \(n) items for good?"
    }

    private var deleteAllButton: String {
        let n = model.deleteAllCandidates?.count ?? 0
        return n == 1 ? "Delete 1 Item" : "Delete \(n) Items"
    }

    private var list: some View {
        List {
            keptText
                .listRowBackground(Color.pn.page)
                .listRowSeparator(.hidden)
            ForEach(model.rows) { row in
                rowView(row)
                    .listRowBackground(Color.pn.page)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func rowView(_ row: RecentlyDeletedModel.Row) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.icon)
                .foregroundColor(Color.pn.ink2)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(PurnoteType.Twin.rowTitle())
                    .foregroundColor(Color.pn.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                Text(row.isRestorable ? "\(row.detail) · Deleted \(row.item.deletedAt.formatted(date: .abbreviated, time: .omitted))"
                                      : "Downloading…")
                    .font(.system(size: detailSize))
                    .foregroundColor(Color.pn.ink2)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            }
            // title and detail read as one element; Restore stays its own button
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if row.isRestorable {
                Button("Restore") { Task { await model.restore(row) } }
                    .buttonStyle(.borderless)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.pn.ribbonText)
                    .accessibilityLabel("Restore \(row.title)")
                    .accessibilityIdentifier("recentlyDeleted.restore")
            }
        }
        .padding(.vertical, 4)
        .opacity(row.isRestorable ? 1 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recentlyDeleted.row")
        .contextMenu {
            if row.isRestorable {
                Button { Task { await model.restore(row) } } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                Button(role: .destructive) { rowPendingDelete = row } label: {
                    Label("Delete Forever", systemImage: "trash")
                }
            }
        }
    }
}
