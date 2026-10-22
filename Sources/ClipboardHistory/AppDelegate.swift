import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var showHistoryMenuItem: NSMenuItem?
    private let monitor = ClipboardMonitor()
    private let hotkey = HotkeyListener()
    private var panelController: HistoryPanelController!
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = HistoryPanelController(monitor: monitor)
        monitor.start()

        hotkey.onTrigger = { [weak self] in
            self?.panelController.toggle()
        }
        if !hotkey.start() {
            showAccessibilityAlert()
        }

        setUpStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.stop()
        monitor.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard History")
        }

        let menu = NSMenu()
        let showItem = menu.addItem(withTitle: showHistoryTitle(), action: #selector(showHistory), keyEquivalent: "")
        showHistoryMenuItem = showItem
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    private func showHistoryTitle() -> String {
        "Show History (\(hotkey.shortcut.displayString))"
    }

    @objc private func showHistory() {
        panelController.show()
    }

    @objc private func clearHistory() {
        monitor.clear()
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(currentShortcut: hotkey.shortcut)
            controller.onShortcutChanged = { [weak self] shortcut in
                guard let self else { return }
                self.hotkey.shortcut = shortcut
                self.showHistoryMenuItem?.title = self.showHistoryTitle()
            }
            settingsWindowController = controller
        }
        settingsWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Needed"
        alert.informativeText = "Clipboard History needs Accessibility access to detect its shortcut and paste for you. Grant it in System Settings → Privacy & Security → Accessibility, then relaunch the app."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
