import AppKit
import ServiceManagement

// MARK: - Small form helpers

private func label(_ text: String, secondary: Bool = false) -> NSTextField {
    let l = NSTextField(wrappingLabelWithString: text)
    if secondary {
        l.textColor = .secondaryLabelColor
        l.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    return l
}

private func check(_ title: String, _ value: Bool, _ change: @escaping (Bool) -> Void) -> NSButton {
    let b = NSButton(checkboxWithTitle: title, target: nil, action: nil)
    b.state = value ? .on : .off
    b.onAction { [unowned b] in change(b.state == .on) }
    return b
}

private func numberField(_ value: Int, _ change: @escaping (Int) -> Void) -> NSTextField {
    let f = NSTextField(string: "\(value)")
    f.alignment = .right
    f.widthAnchor.constraint(equalToConstant: 64).isActive = true
    let formatter = NumberFormatter()
    formatter.allowsFloats = false
    formatter.minimum = 0
    f.formatter = formatter
    f.onAction { [unowned f] in change(f.integerValue) }
    return f
}

private func popup(_ titles: [String], selected: Int, _ change: @escaping (Int) -> Void) -> NSPopUpButton {
    let p = NSPopUpButton()
    p.addItems(withTitles: titles)
    p.selectItem(at: selected)
    p.onAction { [unowned p] in change(p.indexOfSelectedItem) }
    return p
}

private func button(_ title: String, _ click: @escaping () -> Void) -> NSButton {
    let b = NSButton(title: title, target: nil, action: nil)
    b.onAction(click)
    return b
}

private func row(_ views: NSView...) -> NSStackView {
    let s = NSStackView(views: views)
    s.orientation = .horizontal
    s.alignment = .firstBaseline
    s.spacing = 8
    return s
}

private func page(_ views: [NSView]) -> NSView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false
    let container = NSView()
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
        stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -18),
    ])
    return container
}

// MARK: - Options

final class OptionsWindowController: NSWindowController {
    private let db: Database

    init(db: Database) {
        self.db = db
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.tr("Ditty Options")
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 540, height: 400).insetBy(dx: 10, dy: 10))
        tabs.autoresizingMask = [.width, .height]
        for (title, view) in [(L10n.tr("General"), general()), (L10n.tr("Supported Types"), types()), (L10n.tr("Keyboard Shortcuts"), shortcuts()),
                              (L10n.tr("Quick Paste"), quickPaste()), (L10n.tr("About"), about())] {
            let item = NSTabViewItem()
            item.label = title
            item.view = view
            tabs.addTabViewItem(item)
        }
        window.contentView?.addSubview(tabs)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func changed() { AppDelegate.shared.settingsChanged() }

    /// The interface language picker: "System Default" first, then every language in its own name.
    private func languagePopup() -> NSPopUpButton {
        let p = NSPopUpButton()
        p.addItems(withTitles: [L10n.tr("System Default")] + L10n.available.map { $0.name })
        p.selectItem(at: L10n.available.firstIndex { $0.code == S.language }.map { $0 + 1 } ?? 0)
        p.onAction { [weak p] in
            guard let p else { return }
            let i = p.indexOfSelectedItem
            S.language = i == 0 ? "system" : L10n.available[i - 1].code
            AppDelegate.shared.languageChanged()
        }
        return p
    }

    private func general() -> NSView {
        let login = check(L10n.tr("Start Ditty on system startup"), SMAppService.mainApp.status == .enabled) { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                let alert = NSAlert(error: error)
                alert.informativeText = L10n.tr("Ditty could not change its login item. It has to run from the Ditty.app bundle for this to work.")
                alert.runModal()
            }
        }
        return page([
            login,
            row(check(L10n.tr("Maximum number of saved copies"), S.maxEntriesEnabled) { [weak self] in S.maxEntriesEnabled = $0; self?.changed() },
                numberField(S.maxEntries) { [weak self] in S.maxEntries = $0; self?.changed() }),
            row(check(L10n.tr("Paste entries expire after"), S.expireEnabled) { [weak self] in S.expireEnabled = $0; self?.changed() },
                numberField(S.expireDays) { [weak self] in S.expireDays = $0; self?.changed() },
                label(L10n.tr("days"))),
            label(L10n.tr("Sticky clips, clips marked Never Auto Delete and clips inside groups are never removed automatically."), secondary: true),
            check(L10n.tr("Update clip order on paste"), S.updateOrderOnPaste) { S.updateOrderOnPaste = $0 },
            row(label(L10n.tr("Theme:")), popup([L10n.tr("Ditto (default)"), L10n.tr("Dark")], selected: S.darkTheme ? 1 : 0) { [weak self] in
                S.darkTheme = $0 == 1
                self?.changed()
            }),
            row(label(L10n.tr("Language:")), languagePopup()),
            row(label(L10n.tr("Database:")), label(db.path, secondary: true)),
            row(button(L10n.tr("Show in Finder")) { [db] in NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: db.path)]) },
                button(L10n.tr("Delete All Clips…")) { AppDelegate.shared.deleteAllClips() }),
        ])
    }

    private func types() -> NSView {
        page([
            label(L10n.tr("Ditty saves these kinds of clipboard data:")),
            check(L10n.tr("Plain text"), S.saveText) { S.saveText = $0 },
            check(L10n.tr("Rich text (RTF)"), S.saveRTF) { S.saveRTF = $0 },
            check(L10n.tr("HTML"), S.saveHTML) { S.saveHTML = $0 },
            check(L10n.tr("Images"), S.saveImages) { S.saveImages = $0 },
            check(L10n.tr("Files copied in Finder"), S.saveFiles) { S.saveFiles = $0 },
            label(L10n.tr("Copies that an app marks as confidential or temporary — password managers do this — are never saved."), secondary: true),
        ])
    }

    private func shortcuts() -> NSView {
        let recorder = HotKeyRecorder(keyCode: S.hotKeyCode, carbonModifiers: S.hotKeyMods)
        recorder.onChange = { [weak self] code, mods in
            S.hotKeyCode = code
            S.hotKeyMods = mods
            self?.changed()
        }
        let keys: [(String, String)] = [
            ("↩", L10n.tr("Paste the selected clip")),
            ("⇧↩", L10n.tr("Paste as plain text")),
            ("⌘1 – ⌘0  or  ⌃1 – ⌃0", L10n.tr("Paste clip 1 – 10")),
            ("↑ ↓  (⇧ to select several)", L10n.tr("Move through the list")),
            ("⌦  or  ⌘⌫", L10n.tr("Delete the selected clips")),
            ("⌘C", L10n.tr("Copy to the clipboard without pasting")),
            ("F3", L10n.tr("Show the full clip")),
            ("F7", L10n.tr("New group")),
            ("⌥↩", L10n.tr("Clip properties")),
            ("⌫ (empty search)", L10n.tr("Leave the current group")),
            ("⎋", L10n.tr("Clear the search, then close")),
        ]
        let grid = NSGridView(views: keys.map { [label($0.0), label($0.1)] })
        grid.rowSpacing = 4
        grid.columnSpacing = 16
        return page([
            row(label(L10n.tr("Activate Ditty:")), recorder),
            label(L10n.tr("Click the button, then press the new shortcut."), secondary: true),
            label(L10n.tr("In the Ditty window:")),
            grid,
        ])
    }

    private func quickPaste() -> NSView {
        page([
            row(label(L10n.tr("Lines per row:")), numberField(S.linesPerRow) { [weak self] in S.linesPerRow = $0; self?.changed() }),
            row(label(L10n.tr("Font size:")), numberField(S.fontSize) { [weak self] in S.fontSize = $0; self?.changed() }),
            row(label(L10n.tr("Transparency:")), numberField(S.transparency) { [weak self] in S.transparency = $0; self?.changed() }, label("%")),
            row(label(L10n.tr("Show the window:")), popup([L10n.tr("At the text caret"), L10n.tr("At the mouse cursor"), L10n.tr("At its previous position")], selected: S.position) { S.position = $0 }),
            label(L10n.tr("Finding the caret needs the Accessibility permission, and not every app reports it; Ditty falls back to the mouse cursor."), secondary: true),
            check(L10n.tr("Always on top (stay open after pasting or clicking elsewhere)"), S.alwaysOnTop) { [weak self] in S.alwaysOnTop = $0; self?.changed() },
            check(L10n.tr("Show thumbnails for copied images"), S.showThumbnails) { [weak self] in S.showThumbnails = $0; self?.changed() },
        ])
    }

    private func about() -> NSView {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let title = NSTextField(labelWithString: "Ditty")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        return page([
            icon,
            title,
            label(L10n.tr("Version %@", version)),
            label(L10n.tr("An unofficial Mac version of Ditto, the Windows clipboard manager by Scott Brogden (sabrogden.github.io/Ditto). It is not affiliated with or endorsed by the original project.")),
            label(L10n.tr("%lld clips saved.", db.clipCount), secondary: true),
        ])
    }
}

// MARK: - Clip properties

final class PropertiesWindowController: NSWindowController {
    private let db: Database
    private let clip: Clip
    private let originalText: String
    private let textView = NSTextView()
    private let quickPasteField = NSTextField()
    private var neverDelete: NSButton!
    private var groupPopup: NSPopUpButton!
    private var groupIDs: [Int64] = [Database.rootID]
    private let canEditText: Bool

    init(db: Database, clip: Clip) {
        self.db = db
        self.clip = clip
        let sizes = db.formatSizes(clip.id)
        canEditText = clip.isGroup || sizes.contains { $0.type == ClipFormat.text }
        originalText = clip.isGroup ? clip.text : db.fullText(clip.id)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = clip.isGroup ? L10n.tr("Group Properties") : L10n.tr("Clip Properties")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 380, height: 360)
        super.init(window: window)

        let dates = DateFormatter()
        dates.dateStyle = .medium
        dates.timeStyle = .medium
        var info = L10n.tr("Date: %@", dates.string(from: clip.date))
        if let pasted = clip.lastPasteDate { info += "      " + L10n.tr("Last pasted: %@", dates.string(from: pasted)) }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.isRichText = false
        textView.isEditable = canEditText
        textView.allowsUndo = true
        textView.font = NSFont.userFixedPitchFont(ofSize: 12)
        textView.string = originalText
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        scroll.documentView = textView
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        quickPasteField.stringValue = clip.quickPasteText
        quickPasteField.placeholderString = L10n.tr("Extra text to find this clip by when searching")
        neverDelete = check(L10n.tr("Never auto delete"), clip.dontAutoDelete) { _ in }
        neverDelete.isEnabled = !clip.isGroup

        let groups = db.groups().filter { $0.id != clip.id }
        groupIDs += groups.map(\.id)
        groupPopup = popup([L10n.tr("Main List")] + groups.map(\.text), selected: groupIDs.firstIndex(of: clip.parentID) ?? 0) { _ in }

        let formatNames = [ClipFormat.text: L10n.tr("Plain text"), ClipFormat.rtf: L10n.tr("Rich text (RTF)"),
                           ClipFormat.html: L10n.tr("HTML"), ClipFormat.png: L10n.tr("Image (PNG)"),
                           ClipFormat.files: L10n.tr("Files")]
        let formats = sizes.map { "\(formatNames[$0.type] ?? $0.type)  (\(ByteCountFormatter.string(fromByteCount: Int64($0.bytes), countStyle: .file)))" }
        let ok = button(L10n.tr("OK")) { [weak self] in self?.save() }
        ok.keyEquivalent = "\r"
        let cancel = button(L10n.tr("Cancel")) { [weak self] in self?.close() }
        cancel.keyEquivalent = "\u{1b}"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, cancel, ok])

        var views: [NSView] = [label(info, secondary: true), label(clip.isGroup ? L10n.tr("Name:") : (canEditText ? L10n.tr("Text:") : L10n.tr("Description (this clip has no editable text):"))), scroll]
        if !clip.isGroup {
            views += [row(label(L10n.tr("Quick paste text:")), quickPasteField), neverDelete]
        }
        views.append(row(label(L10n.tr("Group:")), groupPopup))
        if !formats.isEmpty { views.append(label(L10n.tr("Saved formats: %@", formats.joined(separator: ", ")), secondary: true)) }
        views.append(buttons)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            quickPasteField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
        ])
        window.center()
        window.initialFirstResponder = textView
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func save() {
        let text = textView.string
        if canEditText, text != originalText, !text.isEmpty {
            if clip.isGroup { db.rename(clip.id, text) } else { db.replaceText(clip.id, text) }
        }
        if !clip.isGroup {
            db.setQuickPasteText(clip.id, quickPasteField.stringValue)
            db.setDontAutoDelete(clip.id, neverDelete.state == .on)
        }
        let group = groupIDs[groupPopup.indexOfSelectedItem]
        if group != clip.parentID { db.setParent([clip.id], group) }
        AppDelegate.shared.quickPaste.clipsChanged()
        close()
    }
}
