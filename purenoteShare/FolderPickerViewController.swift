//
//  FolderPickerViewController.swift
//  purenoteShare
//

import UIKit

/// Lets the user choose where the shared note should land, with drill-in
/// navigation: each folder can be picked ("Save to …") or pushed into to reach
/// its subfolders. A "New Folder…" row creates a folder at the current level.
///
/// Folders come from the catalog the app mirrors into the App Group container,
/// as relative paths from the storage root. One view controller instance is a
/// single level of the tree; tapping a folder pushes the next level with the
/// same `onPick` closure, so a pick anywhere collapses the whole stack.
///
/// Styled to match the app: warm paper background, orange folder icons, plain
/// edge-to-edge rows.
final class FolderPickerViewController: UITableViewController {

    /// Called with the chosen folder path ("" = top level) or nil on cancel.
    private let onPick: (String?) -> Void
    private let selected: String
    /// This level's folder, as a path relative to the storage root.
    private let path: String
    /// The full catalog, passed down so deeper levels can compute their own
    /// children.
    private let folders: [String]
    /// This level's direct subfolders, as full relative paths.
    private let subfolders: [String]

    init(path: String, folders: [String], selected: String, onPick: @escaping (String?) -> Void) {
        self.path = path
        self.selected = selected
        self.onPick = onPick
        self.folders = folders
        self.subfolders = SharedInbox.childFolders(of: path, in: folders)
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = path.isEmpty ? "Save to" : (path as NSString).lastPathComponent

        view.backgroundColor = .purnotePaper
        tableView.backgroundColor = .purnotePaper
        tableView.separatorColor = .separator
        // orange checkmarks, matching the app's accent
        tableView.tintColor = .purnoteAmber

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .purnotePaper
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .purnoteAmber

        if path.isEmpty {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }
    }

    @objc private func cancel() { onPick(nil) }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1                  // save to this folder
        case 1: return subfolders.count   // drill into subfolders
        default: return 1                 // new folder
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1: return subfolders.isEmpty ? nil : "Subfolders"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .purnotePaper
        switch indexPath.section {
        case 0:
            var content = cell.defaultContentConfiguration()
            content.text = path.isEmpty ? "Notes" : "Save to \((path as NSString).lastPathComponent)"
            content.image = UIImage(systemName: path.isEmpty ? "note.text" : "folder")
            content.imageProperties.tintColor = .purnoteAmber
            cell.contentConfiguration = content
            cell.accessoryType = (selected == path) ? .checkmark : .none

        case 1:
            let subfolder = subfolders[indexPath.row]
            var content = cell.defaultContentConfiguration()
            content.text = (subfolder as NSString).lastPathComponent
            content.image = UIImage(systemName: "folder")
            content.imageProperties.tintColor = .purnoteAmber
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator

        default:
            var content = cell.defaultContentConfiguration()
            content.text = "New Folder\u{2026}"
            content.image = UIImage(systemName: "folder.badge.plus")
            content.imageProperties.tintColor = .purnoteAmber
            cell.contentConfiguration = content
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            onPick(path)
        case 1:
            let subfolder = subfolders[indexPath.row]
            let next = FolderPickerViewController(path: subfolder, folders: folders,
                                                  selected: selected, onPick: onPick)
            navigationController?.pushViewController(next, animated: true)
        default:
            promptForNewFolder()
        }
    }

    /// A new folder is created inside the current folder; the app makes the
    /// real directory when it imports the note.
    private func promptForNewFolder() {
        let alert = UIAlertController(title: "New Folder",
                                      message: "The note will be saved into this new folder.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Folder name" }
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            self.onPick(self.path.isEmpty ? name : self.path + "/" + name)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
