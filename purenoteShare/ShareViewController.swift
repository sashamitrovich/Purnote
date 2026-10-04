//
//  ShareViewController.swift
//  purenoteShare
//

import UIKit

/// The share extension's whole interface: a preview of what was shared, which
/// the user can trim before saving, a destination picker for the folder, and
/// the two obvious buttons.
///
/// The note is written into the App Group inbox (optionally under the chosen
/// folder); the app moves it into its own storage the next time it opens, so a
/// shared post is just another `.md` file and turns up in the app on its own.
final class ShareViewController: UIViewController {

    private let textView = UITextView()
    private var saveButton: UIBarButtonItem?
    private var destinationButton: UIBarButtonItem?

    /// The folder the note will land in, as a path relative to the storage
    /// root ("" = top level).
    private var destination = "" {
        didSet { updateDestinationButton() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: "Save to Purnote")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        let destinationItem = UIBarButtonItem(
            title: "Notes", style: .plain, target: self, action: #selector(chooseFolder))
        destinationButton = destinationItem
        let save = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(save))
        save.isEnabled = false
        navItem.rightBarButtonItems = [save, destinationItem]
        navBar.items = [navItem]
        saveButton = save
        view.addSubview(navBar)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .preferredFont(forTextStyle: .body)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            textView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        Task { await loadSharedContent() }
    }

    // MARK: - Reading what was shared

    private func loadSharedContent() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        var text: String?
        var url: String?

        for item in items {
            for provider in item.attachments ?? [] {
                if text == nil, provider.hasItemConformingToTypeIdentifier("public.text"),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: "public.text") as? String,
                   !loaded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = loaded
                }
                if url == nil, provider.hasItemConformingToTypeIdentifier("public.url") {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: "public.url")
                    url = (loaded as? URL)?.absoluteString ?? (loaded as? String)
                }
            }
        }

        let content = ShareContent.note(text: text, url: url)
        textView.text = content
        saveButton?.isEnabled = !content.isEmpty
    }

    // MARK: - Actions

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.mitrovic.purenote.share", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
    }

    @objc private func chooseFolder() {
        let folders = SharedInbox.catalogURL().map { SharedInbox.readCatalog(from: $0) } ?? []
        let picker = FolderPickerViewController(path: "", folders: folders, selected: destination) { [weak self] picked in
            guard let self else { return }
            if let picked {
                self.destination = picked
            }
            self.dismiss(animated: true)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func updateDestinationButton() {
        let name = destination.isEmpty ? "Notes" : (destination as NSString).lastPathComponent
        destinationButton?.title = name
    }

    @objc private func save() {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // The note goes into the App Group inbox, under the chosen folder; the
        // app moves it into its storage (iCloud Drive or local) the next time
        // it opens. The extension cannot reach the app's own Documents folder,
        // so the shared inbox is the hand-off point.
        guard let inbox = SharedInbox.inboxURL else {
            present(alert: "Couldn't save",
                    message: "Purnote couldn't access its shared storage. Try again.")
            return
        }

        do {
            try SharedInbox.save(content, to: inbox, in: destination)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            present(alert: "Couldn't save",
                    message: "Purnote could not write this note. Try again in a moment.")
        }
    }

    private func present(alert title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
