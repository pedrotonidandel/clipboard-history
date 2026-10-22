import AppKit

/// A single Settings window with a toolbar that swaps panes, matching the
/// standard macOS System Settings / app-preferences pattern (General, About).
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private static let generalIdentifier = NSToolbarItem.Identifier("general")
    private static let aboutIdentifier = NSToolbarItem.Identifier("about")

    private let generalViewController: GeneralPreferencesViewController
    private let aboutViewController = AboutViewController()

    var onShortcutChanged: ((HotkeyShortcut) -> Void)?

    init(currentShortcut: HotkeyShortcut) {
        generalViewController = GeneralPreferencesViewController(currentShortcut: currentShortcut)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        generalViewController.onShortcutChanged = { [weak self] shortcut in
            self?.onShortcutChanged?(shortcut)
        }

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = Self.generalIdentifier
        window.toolbar = toolbar
        window.toolbarStyle = .preference

        showPane(generalViewController, title: "General")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPane(_ viewController: NSViewController, title: String) {
        guard let window else { return }
        window.title = title
        let targetSize = viewController.view.frame.size
        window.contentViewController = viewController

        var frame = window.frame
        let contentRect = window.contentRect(forFrameRect: frame)
        let deltaHeight = targetSize.height - contentRect.height
        let deltaWidth = targetSize.width - contentRect.width
        frame.size.height += deltaHeight
        frame.size.width += deltaWidth
        frame.origin.y -= deltaHeight
        window.setFrame(frame, display: true, animate: true)
    }

    @objc private func selectGeneral() {
        window?.toolbar?.selectedItemIdentifier = Self.generalIdentifier
        showPane(generalViewController, title: "General")
    }

    @objc private func selectAbout() {
        window?.toolbar?.selectedItemIdentifier = Self.aboutIdentifier
        showPane(aboutViewController, title: "About")
    }

    // MARK: - NSToolbarDelegate

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.generalIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "General"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
            item.target = self
            item.action = #selector(selectGeneral)
            return item
        case Self.aboutIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "About"
            item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
            item.target = self
            item.action = #selector(selectAbout)
            return item
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalIdentifier, Self.aboutIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalIdentifier, Self.aboutIdentifier]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.generalIdentifier, Self.aboutIdentifier]
    }
}
