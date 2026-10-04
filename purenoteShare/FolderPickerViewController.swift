//
//  FolderPickerViewController.swift
//  purenoteShare
//

import UIKit

/// Lets the user choose where the shared note should land: the top level
/// ("Notes"), one of the app's existing folders, or a new folder.
///
/// Folders come from the catalog the app mirrors into the App Group container,
/// as relative paths from the storage root. The picker shows the last path
/// component as the title (indented by depth), so nested folders read cleanly.
final class FolderPickerViewController: UITableViewController {

    /// Called with the chosen folder ("" = top level) or nil on cancel.
    private let onPick: (String?) -> Void
    private let folders: [String]
    private let selected: String

    private struct Row {
        let title: String
        let path: String
        let depth: Int
    }

    private lazy var rows: [Row] = {
        [Row(title: "Notes", path: "", depth: 0)]
            + folders.map {
                Row(title: ($0 as NSString).lastPathComponent,
                    path: $0,
                    depth: $0.components(separatedBy: "/").count)
            }
    }()

    init(folders: [String], selected: String, onPick: @escaping (String?) -> Void) {
        self.folders = folders
        self.selected = selected
        self.onPick = onPick
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Save to"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }

    @objc private func cancel() { onPick(nil) }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? rows.count : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if indexPath.section == 0 {
            let row = rows[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = row.title
            content.image = UIImage(systemName: row.path.isEmpty ? "note.text" : "folder")
            content.secondaryText = row.path.isEmpty || row.depth <= 1 ? nil : row.path
            cell.contentConfiguration = content
            cell.indentationLevel = row.depth
            cell.accessoryType = (row.path == selected) ? .checkmark : .none
        } else {
            var content = cell.defaultContentConfiguration()
            content.text = "New Folder\u{2026}"
            content.image = UIImage(systemName: "folder.badge.plus")
            cell.contentConfiguration = content
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            onPick(rows[indexPath.row].path)
        } else {
            promptForNewFolder()
        }
    }

    /// A new folder is created at the top level; the app makes the real
    /// directory when it imports the note.
    private func promptForNewFolder() {
        let alert = UIAlertController(title: "New Folder",
                                      message: "The note will be saved into this new folder.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Folder name" }
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            self?.onPick(name)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
