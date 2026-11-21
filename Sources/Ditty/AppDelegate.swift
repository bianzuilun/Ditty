import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    private(set) var db: Database!
    private(set) var monitor: ClipboardMonitor!
    private(set) var quickPaste: QuickPasteController!
    private var statusItem: NSStatusItem!
    private var optionsWindow: OptionsWindowController?
    private var propertiesWindow: PropertiesWindowController?
    private var accessibilityExplained = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--make-icon"), i + 1 < args.count {
            Icons.writeAppIcon(to: args[i + 1])
            exit(0)
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            snapshot(to: args[i + 1])
            exit(0)
        }
        if let i = args.firstIndex(of: "--options-snapshot"), i + 1 < args.count {
            let tab = args.firstIndex(of: "--tab").flatMap { Int(args[$0 + 1]) } ?? 0
            optionsSnapshot(to: args[i + 1], tab: tab)
            exit(0)
        }

        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0 != NSRunningApplication.current }) {
            NSApp.terminate(nil)
            return
        }

        NSApp.mainMenu = makeMainMenu()
        db = Database(path: S.databasePath)
        quickPaste = QuickPasteController(db: db)
        monitor = ClipboardMonitor(db: db)
        monitor.onNewClip = { [weak self] id in
            self?.quickPaste.currentClipID = id
            self?.quickPaste.clipsChanged()
        }
        monitor.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.toolTip = "Ditty"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()
        registerHotKey()
        trim()

        if !S.firstRunDone {
            S.firstRunDone = true
            Paster.requestAccessibility()
            quickPaste.show()
        }
    }

    /// Opening Ditty again while it is running shows the popup, as launching Ditto twice does on Windows.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !(optionsWindow?.window?.isVisible ?? false), !(propertiesWindow?.window?.isVisible ?? false) {
            quickPaste?.show()
        }
        return false
    }

    // MARK: - Menu bar

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = statusMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            quickPaste.toggle()
        }
    }

    private func statusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let hotKey = KeyNames.describe(keyCode: S.hotKeyCode, carbonModifiers: S.hotKeyMods)
        [
            NSMenuItem(L10n.tr("Show Ditty    %@", hotKey)) { [weak self] in self?.quickPaste.show() },
            .separator(),
            NSMenuItem(L10n.tr("Options…")) { [weak self] in self?.showOptions() },
            NSMenuItem(S.connected ? L10n.tr("Disconnect from Clipboard") : L10n.tr("Connect to Clipboard")) { [weak self] in self?.toggleConnected() },
            NSMenuItem(L10n.tr("Delete All Clips…")) { [weak self] in self?.deleteAllClips() },
            .separator(),
            NSMenuItem(L10n.tr("Exit")) { NSApp.terminate(nil) },
        ].forEach(menu.addItem)
        return menu
    }

    private func updateStatusIcon() {
        statusItem.button?.image = Icons.statusIcon(connected: S.connected)
    }

    /// An accessory app shows no menu bar, but the Edit menu still supplies Cmd+C/V/X/A/Z to its text fields.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let app = NSMenuItem()
        app.submenu = NSMenu()
        app.submenu?.addItem(withTitle: L10n.tr("Quit Ditty"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(app)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: L10n.tr("Edit"))
        editMenu.addItem(withTitle: L10n.tr("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.tr("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.tr("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.tr("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.tr("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.tr("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        main.addItem(edit)
        return main
    }

    // MARK: - Actions shared by the menus and windows

    private func registerHotKey() {
        let ok = HotKeyCenter.shared.register(id: 1, keyCode: S.hotKeyCode, carbonModifiers: S.hotKeyMods) { [weak self] in
            self?.quickPaste.toggle()
        }
        if !ok { NSLog("Ditty: could not register the activation hot key") }
    }

    private func trim() {
        db.trim(maxEntries: S.maxEntriesEnabled ? S.maxEntries : nil, expireDays: S.expireEnabled ? S.expireDays : nil)
    }

    func settingsChanged() {
        registerHotKey()
        trim()
        quickPaste.applySettings()
    }

    func toggleConnected() {
        S.connected.toggle()
        updateStatusIcon()
    }

    /// Rebuilds every window so a language change is visible right away. Menus are created on
    /// demand, so only the options window has to be replaced and the popup refreshed.
    func languageChanged() {
        let reopen = optionsWindow?.window?.isVisible ?? false
        optionsWindow?.window?.orderOut(nil)
        optionsWindow = nil
        settingsChanged()
        if reopen { showOptions() }
    }

    func showOptions() {
        quickPaste.hide(returnFocus: false)
        if optionsWindow == nil { optionsWindow = OptionsWindowController(db: db) }
        NSApp.activate(ignoringOtherApps: true)
        optionsWindow?.showWindow(nil)
        optionsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    func showProperties(for id: Int64) {
        guard let clip = db.clip(id) else { return }
        propertiesWindow?.close()
        propertiesWindow = PropertiesWindowController(db: db, clip: clip)
        NSApp.activate(ignoringOtherApps: true)
        propertiesWindow?.showWindow(nil)
        propertiesWindow?.window?.makeKeyAndOrderFront(nil)
    }

    func deleteAllClips() {
        quickPaste.hide(returnFocus: false)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.tr("Delete all clips?")
        alert.informativeText = L10n.tr("This removes every saved copy except sticky clips, clips marked Never Auto Delete and clips inside groups. It cannot be undone.")
        alert.addButton(withTitle: L10n.tr("Delete"))
        alert.addButton(withTitle: L10n.tr("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            db.deleteAllDisposable()
            quickPaste.clipsChanged()
        }
    }

    /// Without the Accessibility permission macOS drops the simulated Cmd+V, so say so instead of failing silently.
    func explainAccessibility() {
        guard !accessibilityExplained else { return }
        accessibilityExplained = true
        let alert = NSAlert()
        alert.messageText = L10n.tr("Ditty needs the Accessibility permission to paste for you")
        alert.informativeText = L10n.tr("The clip is on your clipboard, so you can press ⌘V yourself right now.\n\nTo let Ditty paste automatically, turn on Ditty under System Settings → Privacy & Security → Accessibility.")
        alert.addButton(withTitle: L10n.tr("Open System Settings"))
        alert.addButton(withTitle: L10n.tr("Not Now"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Paster.requestAccessibility()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Snapshot

    /// Renders the popup with sample clips into a PNG, using a throwaway database.
    private func snapshot(to path: String) {
        let temp = NSTemporaryDirectory() + "ditty-snapshot-\(ProcessInfo.processInfo.processIdentifier).db"
        db = Database(path: temp)
        let samples = ["search", "paste plain text", "view copied images", "send clip to network computers",
                       "compare clips in diff app", "copy", "paste"]
        for text in samples {
            db.addClip(text: text, formats: [ClipFormat(type: ClipFormat.text, data: Data(text.utf8))], crc: Database.crc(Data(text.utf8)))
        }
        quickPaste = QuickPasteController(db: db)
        quickPaste.currentClipID = db.fetch(parent: Database.rootID, search: "").last?.id
        quickPaste.snapshot(to: path)
        for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: temp + suffix) }
    }

    /// Renders the options window with the given tab (0 General … 4 About) into a PNG,
    /// so UI changes can be checked without screen-recording permission. The window is
    /// put on screen for a moment, because system (dynamic) colours only resolve there.
    private func optionsSnapshot(to path: String, tab: Int) {
        let temp = NSTemporaryDirectory() + "ditty-options-\(ProcessInfo.processInfo.processIdentifier).db"
        let controller = OptionsWindowController(db: Database(path: temp))
        guard let window = controller.window, let view = window.contentView else { return }
        window.center()
        if let tabs = view.subviews.compactMap({ $0 as? NSTabView }).first, tab < tabs.numberOfTabViewItems {
            tabs.selectTabViewItem(at: tab)
        }
        window.orderFrontRegardless()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        defer { window.orderOut(nil) }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        // cacheDisplay leaves the window background out, so composite the content over it.
        let size = view.bounds.size
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let cg = rep.cgImage {
            NSImage(cgImage: cg, size: size).draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        }
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff) {
            try? png.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: temp + suffix) }
    }
}
