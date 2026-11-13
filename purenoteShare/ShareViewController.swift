//
//  ShareViewController.swift
//  purenoteShare
//

import UIKit

/// The share extension's whole interface, in the 1.5 "Margin" design: Purnote's
/// own sheet with the shared text as editable styled source (first line set as
/// a title), a line saying where the note will
/// go and what its file will be called, the folder list with a tick, and the
/// two obvious buttons.
///
/// The note is written into the App Group inbox (optionally under the chosen
/// folder); the app moves it into its own storage the next time it opens, so a
/// shared post is just another `.md` file and turns up in the app on its own.
///
/// What is saved is exactly the text in the field. The title styling is
/// drawing only: nothing is added to the text.
final class ShareViewController: UIViewController {

    // MARK: Views

    private let closeButton = UIButton(configuration: .filled())
    private let saveButton = UIButton(configuration: .filled())
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let textView = UITextView()
    private let folderHeader = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let footnote = UILabel()

    // MARK: State

    private let sideInset: CGFloat = 16

    /// The folder the note will land in, as a path relative to the storage
    /// root ("" = top level). Defaults to the folder used last time.
    private var destination = "" {
        didSet {
            updateSummary()
            tableView.reloadData()
        }
    }

    /// The folder catalog the app mirrored, plus folders created in this sheet
    /// (the app makes the real directory when it imports the note).
    private var folders: [String] = []
    private var rows: [Row] = []

    private enum Row: Equatable {
        case top
        case folder(path: String, depth: Int)
        case newFolder
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .pnSheet

        buildHeader()
        buildSummary()
        buildText()
        buildFolderList()
        buildFootnote()
        layoutViews()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.restyle()
            self.updateSummary()
            self.tableView.reloadData()
        }

        // Start where the user left off last time.
        folders = SharedInbox.catalogURL().map { SharedInbox.readCatalog(from: $0) } ?? []
        rebuildRows()
        destination = SharedInbox.suggestedFolder(lastUsed: SharedInbox.lastSharedFolder(), in: folders)

        Task { await loadSharedContent() }
    }

    // MARK: - Building the interface

    private func buildHeader() {
        var close = closeButton.configuration ?? .filled()
        close.image = UIImage(systemName: "xmark",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        close.baseBackgroundColor = .pnFill
        close.baseForegroundColor = .pnInk
        close.cornerStyle = .capsule
        closeButton.configuration = close
        closeButton.accessibilityLabel = "Cancel"
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        var saveConfig = saveButton.configuration ?? .filled()
        saveConfig.title = "Save"
        saveConfig.baseBackgroundColor = .pnRibbon
        saveConfig.baseForegroundColor = .pnOnRibbon
        saveConfig.cornerStyle = .capsule
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        saveConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = PNFont.ui(weight: .semibold, maximum: 26)
            return attributes
        }
        saveButton.configuration = saveConfig
        saveButton.isEnabled = false
        saveButton.configurationUpdateHandler = { button in
            button.alpha = button.isEnabled ? 1 : 0.4
        }
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        saveButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.text = "Save to Purnote"
        titleLabel.font = PNFont.sheetTitle()
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .pnInk
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.accessibilityTraits = .header
    }

    private func buildSummary() {
        summaryLabel.numberOfLines = 0
        summaryLabel.adjustsFontForContentSizeCategory = true
    }

    private func buildText() {
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 12, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.tintColor = .pnRibbon
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.delegate = self
        textView.accessibilityLabel = "Note text"
    }

    private func buildFolderList() {
        let caption = UILabel()
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.attributedText = NSAttributedString(string: "FOLDER", attributes: [
            .font: PNFont.caps(), .foregroundColor: UIColor.pnInk2, .kern: PNFont.capsTracking,
        ])
        caption.adjustsFontForContentSizeCategory = true
        caption.accessibilityTraits = .header
        caption.setContentHuggingPriority(.required, for: .horizontal)

        let hairline = UIView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = .pnRule

        folderHeader.translatesAutoresizingMaskIntoConstraints = false
        folderHeader.addSubview(caption)
        folderHeader.addSubview(hairline)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: folderHeader.leadingAnchor),
            caption.topAnchor.constraint(equalTo: folderHeader.topAnchor, constant: 8),
            caption.bottomAnchor.constraint(equalTo: folderHeader.bottomAnchor, constant: -8),
            hairline.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
            hairline.trailingAnchor.constraint(equalTo: folderHeader.trailingAnchor),
            hairline.centerYAnchor.constraint(equalTo: caption.centerYAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])

        tableView.backgroundColor = .clear
        tableView.separatorColor = .pnRule
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset.bottom = 8
    }

    private func buildFootnote() {
        footnote.numberOfLines = 0
        footnote.font = PNFont.meta()
        footnote.adjustsFontForContentSizeCategory = true
        footnote.textColor = .pnInk2
        footnote.text = "Saved as plain Markdown. Edit the title or text here before saving."
    }

    private func layoutViews() {
        for item in [closeButton, saveButton, titleLabel, summaryLabel, textView, folderHeader, tableView, footnote] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        let guide = view.safeAreaLayoutGuide

        let summaryTop = summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22)
        summaryTop.priority = .defaultHigh
        summaryTop.isActive = true

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            saveButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),
            saveButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            titleLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveButton.leadingAnchor, constant: -8),

            summaryLabel.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 22),
            summaryLabel.topAnchor.constraint(greaterThanOrEqualTo: closeButton.bottomAnchor, constant: 22),
            summaryLabel.topAnchor.constraint(greaterThanOrEqualTo: saveButton.bottomAnchor, constant: 22),
            summaryLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            summaryLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),

            textView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),
            textView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.32),

            folderHeader.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            folderHeader.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            folderHeader.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),

            tableView.topAnchor.constraint(equalTo: folderHeader.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            tableView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),
            tableView.bottomAnchor.constraint(equalTo: footnote.topAnchor, constant: -4),

            footnote.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: sideInset),
            footnote.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -sideInset),
            footnote.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
    }

    // MARK: - Styling the text

    private var titleRange: NSRange? {
        let text = textView.text as NSString
        var location = 0
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            let line = text.substring(with: paragraph)
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return paragraph
            }
            location = NSMaxRange(paragraph)
        }
        return nil
    }

    /// Draws the first line as the title and the rest as quiet serif source,
    /// bare links in the amber link colour. Attributes only: the characters
    /// are never touched. Skipped while an input method is composing.
    private func restyle() {
        guard textView.markedTextRange == nil else { return }
        let storage = textView.textStorage
        let traits = textView.traitCollection
        let text = storage.string as NSString
        let full = NSRange(location: 0, length: storage.length)

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 4
        bodyParagraph.paragraphSpacing = 10
        let body: [NSAttributedString.Key: Any] = [
            .font: PNFont.body(compatibleWith: traits),
            .foregroundColor: UIColor.pnInk2,
            .paragraphStyle: bodyParagraph,
        ]

        let title = titleRange
        let titleText = title.map { text.substring(with: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.paragraphSpacing = 14
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleText.count > 32 ? PNFont.titleLong(compatibleWith: traits) : PNFont.title(compatibleWith: traits),
            .foregroundColor: UIColor.pnInk,
            .paragraphStyle: titleParagraph,
        ]

        storage.beginEditing()
        storage.setAttributes(body, range: full)
        if let title { storage.setAttributes(titleAttributes, range: title) }
        var location = title.map { NSMaxRange($0) } ?? 0
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            let line = text.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
            if (line.hasPrefix("http://") || line.hasPrefix("https://")) && !line.contains(" ") {
                storage.addAttribute(.foregroundColor, value: UIColor.pnRibbonText, range: paragraph)
            }
            location = NSMaxRange(paragraph)
        }
        storage.endEditing()

        if storage.length == 0 || title == nil {
            textView.typingAttributes = titleAttributes
        }
    }

    private func updateSummary() {
        let target = ShareContent.saveTarget(folder: destination, content: textView.text ?? "")
        summaryLabel.attributedText = NSAttributedString(string: target.line.uppercased(), attributes: [
            .font: PNFont.caps(compatibleWith: traitCollection),
            .foregroundColor: UIColor.pnInk2,
            .kern: PNFont.capsTracking,
        ])
        summaryLabel.accessibilityLabel = target.line
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

        show(ShareContent.note(text: text, url: url))
    }

    private func show(_ content: String) {
        textView.text = content
        restyle()
        updateSummary()
        saveButton.isEnabled = !content.isEmpty
    }

    // MARK: - Actions

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.mitrovic.purenote.share", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
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
            SharedInbox.rememberSharedFolder(destination)
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

    // MARK: - Folders

    private func rebuildRows() {
        rows = [.top]
        for path in SharedInbox.treeOrder(folders) {
            rows.append(.folder(path: path, depth: path.split(separator: "/").count - 1))
        }
        rows.append(.newFolder)
    }

    /// A new folder is created inside the folder chosen now; the app makes the
    /// real directory when it imports the note.
    private func promptForNewFolder() {
        let parent = destination
        let alert = UIAlertController(title: "New Folder",
                                      message: "The note will be saved into this new folder.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Folder name" }
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            let path = parent.isEmpty ? name : parent + "/" + name
            if !self.folders.contains(path) {
                self.folders.append(path)
                self.rebuildRows()
            }
            self.destination = path
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - Text editing

extension ShareViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        restyle()
        updateSummary()
    }
}

// MARK: - Folder list

extension ShareViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        let selectedBackground = UIView()
        selectedBackground.backgroundColor = .pnFill
        cell.selectedBackgroundView = selectedBackground

        var content = UIListContentConfiguration.cell()
        content.textProperties.font = PNFont.ui()
        content.textProperties.color = .pnInk
        content.imageProperties.tintColor = .pnInk2
        content.directionalLayoutMargins.leading = 0
        content.directionalLayoutMargins.trailing = 0

        var isChosen = false
        switch rows[indexPath.row] {
        case .top:
            content.text = "Notes"
            content.image = UIImage(systemName: "note.text")
            isChosen = destination.isEmpty
            cell.indentationLevel = 0
        case .folder(let path, let depth):
            content.text = (path as NSString).lastPathComponent
            content.image = UIImage(systemName: "folder")
            isChosen = (destination == path)
            cell.indentationLevel = depth
        case .newFolder:
            content.text = "New Folder\u{2026}"
            content.image = UIImage(systemName: "folder.badge.plus")
            content.imageProperties.tintColor = .pnRibbonText
            cell.indentationLevel = 0
        }
        cell.indentationWidth = 20
        cell.contentConfiguration = content

        if isChosen {
            let tick = UIImageView(image: UIImage(systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)))
            tick.tintColor = .pnRibbonText
            tick.sizeToFit()
            cell.accessoryView = tick
            cell.accessibilityTraits.insert(.selected)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row] {
        case .top: destination = ""
        case .folder(let path, _): destination = path
        case .newFolder: promptForNewFolder()
        }
    }
}
