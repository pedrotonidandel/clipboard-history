import AppKit
import Carbon.HIToolbox.Events

/// A table view that treats Return as "confirm selection", Escape as
/// "cancel", and digits 1-9/0 as "jump straight to that row and confirm" —
/// instead of swallowing them silently.
final class HistoryTableView: NSTableView {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    var onQuickSelect: ((Int) -> Void)?

    private static let digitKeyCodes: [UInt16: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9
    ]

    override func keyDown(with event: NSEvent) {
        if let index = HistoryTableView.digitKeyCodes[event.keyCode] {
            onQuickSelect?(index)
            return
        }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onConfirm?()
        case kVK_Escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

/// A borderless, non-activating panel: it can become key (so the table view
/// gets keyboard events) without stealing focus from the app the user was
/// just typing into, and without showing up in the Dock/Cmd+Tab switcher.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Draws selection as a soft, inset, rounded "chip" (Raycast/Spotlight
/// style) instead of AppKit's default hard-edged full-width highlight.
private final class HistoryRowBackgroundView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }
        let inset = bounds.insetBy(dx: 6, dy: 1)
        let path = NSBezierPath(roundedRect: inset, xRadius: 9, yRadius: 9)
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        // Fully custom — no default row background.
    }
}

private final class HistoryRowView: NSTableCellView {
    let iconChip = NSView()
    let icon = NSImageView()
    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let kbd = NSTextField(labelWithString: "")
    private let kbdBackground = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)

        iconChip.wantsLayer = true
        iconChip.layer?.cornerRadius = 8
        iconChip.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        iconChip.translatesAutoresizingMaskIntoConstraints = false

        icon.symbolConfiguration = .init(pointSize: 13, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconChip.addSubview(icon)

        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail

        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = .tertiaryLabelColor

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        kbdBackground.wantsLayer = true
        kbdBackground.layer?.cornerRadius = 5
        kbdBackground.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        kbdBackground.translatesAutoresizingMaskIntoConstraints = false

        kbd.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        kbd.textColor = .tertiaryLabelColor
        kbd.alignment = .center
        kbd.translatesAutoresizingMaskIntoConstraints = false
        kbdBackground.addSubview(kbd)

        for view in [iconChip, textStack, kbdBackground] {
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            iconChip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconChip.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconChip.widthAnchor.constraint(equalToConstant: 28),
            iconChip.heightAnchor.constraint(equalToConstant: 28),
            icon.centerXAnchor.constraint(equalTo: iconChip.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconChip.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconChip.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: kbdBackground.leadingAnchor, constant: -8),

            kbdBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            kbdBackground.centerYAnchor.constraint(equalTo: centerYAnchor),
            kbdBackground.widthAnchor.constraint(equalToConstant: 18),
            kbdBackground.heightAnchor.constraint(equalToConstant: 18),
            kbd.centerXAnchor.constraint(equalTo: kbdBackground.centerXAnchor),
            kbd.centerYAnchor.constraint(equalTo: kbdBackground.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func symbolName(for text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return "link"
        }
        if text.contains("\n") {
            return "text.alignleft"
        }
        return "doc.on.clipboard"
    }
}

final class HistoryPanelController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let panel: HistoryPanel
    private let tableView = HistoryTableView()
    private let headerLabel = NSTextField(labelWithString: "Clipboard History")
    private let headerIcon = NSImageView()
    private let monitor: ClipboardMonitor
    private var previousApp: NSRunningApplication?

    private static let rowHeight: CGFloat = 46
    private static let headerHeight: CGFloat = 34
    private static let panelWidth: CGFloat = 360

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
        panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.rowHeight * 10 + Self.headerHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self

        headerLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        headerIcon.image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)
        headerIcon.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
        headerIcon.contentTintColor = .controlAccentColor
        headerIcon.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: .init("text"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Self.rowHeight
        tableView.backgroundColor = .clear
        tableView.autoresizingMask = [.width]
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.style = .plain
        // We draw our own rounded "chip" selection (see HistoryRowBackgroundView).
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(confirmSelection) // single click pastes immediately
        tableView.onConfirm = { [weak self] in self?.confirmSelection() }
        tableView.onCancel = { [weak self] in self?.hide() }
        tableView.onQuickSelect = { [weak self] index in self?.quickSelect(index) }

        scrollView.documentView = tableView

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 18
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(headerIcon)
        visualEffect.addSubview(headerLabel)
        visualEffect.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerIcon.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 15),
            headerIcon.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 18),

            headerLabel.centerYAnchor.constraint(equalTo: headerIcon.centerYAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: headerIcon.trailingAnchor, constant: 7),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -8),
            scrollView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -6)
        ])

        panel.contentView = visualEffect
    }

    /// Called by the global shortcut. Unlike `show()` (used by the menu
    /// item, which always works), this does nothing if there's no editable
    /// text field focused — so pressing the shortcut on the Desktop, in a
    /// list, etc. doesn't pop up a useless popup with nowhere to paste.
    func toggle() {
        if panel.isVisible {
            hide()
        } else if CaretLocator.isEditableTextFocused() {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        tableView.reloadData()

        let rowCount = max(monitor.items.count, 1)
        let height = Self.rowHeight * CGFloat(min(rowCount, 10)) + Self.headerHeight + 14
        var frame = panel.frame
        frame.size = NSSize(width: Self.panelWidth, height: height)
        frame.origin = preferredOrigin(for: frame.size)
        panel.setFrame(frame, display: true)

        panel.makeKeyAndOrderFront(nil)
        if !monitor.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        panel.makeFirstResponder(tableView)
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Anchors the popup right under the text caret of whatever app the user
    /// is typing in (via Accessibility), falling back to the mouse location
    /// when the frontmost app doesn't expose caret info. Flips to above the
    /// anchor when there isn't room below (e.g. near the Dock), and always
    /// stays fully inside the screen's visible area (never over the Dock or
    /// menu bar).
    private func preferredOrigin(for size: NSSize) -> NSPoint {
        let margin: CGFloat = 10
        let anchor = CaretLocator.focusedCaretBottomLeft() ?? fallbackAnchor()
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            return NSPoint(x: anchor.x, y: anchor.y)
        }

        let spaceBelow = anchor.y - visibleFrame.minY
        let spaceAbove = visibleFrame.maxY - anchor.y
        let y: CGFloat
        if spaceBelow >= size.height + margin || spaceBelow >= spaceAbove {
            y = anchor.y - size.height - margin
        } else {
            y = anchor.y + margin
        }

        var origin = NSPoint(x: anchor.x, y: y)
        origin.x = min(max(origin.x, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        origin.y = min(max(origin.y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)
        return origin
    }

    private func fallbackAnchor() -> NSPoint {
        NSEvent.mouseLocation
    }

    private func quickSelect(_ index: Int) {
        guard index < monitor.items.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        confirmSelection()
    }

    @objc private func confirmSelection() {
        // Guards against a double-click firing this twice (once per click)
        // and pasting the same item two times.
        guard panel.isVisible else { return }

        let row = tableView.selectedRow
        guard row >= 0, row < monitor.items.count else {
            hide()
            return
        }
        let item = monitor.items[row]
        hide()

        monitor.suppressNextCapture(of: item.text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)

        let appToRestore = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            appToRestore?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                Self.simulatePasteKeystroke()
            }
        }
    }

    private static func simulatePasteKeystroke() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        monitor.items.isEmpty ? 1 : monitor.items.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        HistoryRowBackgroundView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("row")
        let view: HistoryRowView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryRowView {
            view = reused
        } else {
            view = HistoryRowView(frame: .zero)
            view.identifier = identifier
        }

        if monitor.items.isEmpty {
            view.icon.image = NSImage(systemSymbolName: "tray", accessibilityDescription: nil)
            view.title.stringValue = "No clipboard history yet"
            view.title.textColor = .secondaryLabelColor
            view.subtitle.stringValue = "Copy something to see it here"
            view.kbd.stringValue = ""
        } else {
            let item = monitor.items[row]
            view.icon.image = NSImage(systemSymbolName: HistoryRowView.symbolName(for: item.text), accessibilityDescription: nil)
            view.title.stringValue = item.preview
            view.title.textColor = .labelColor
            view.subtitle.stringValue = Self.relativeTime(from: item.date)
            view.kbd.stringValue = row < 9 ? "\(row + 1)" : (row == 9 ? "0" : "")
        }
        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !monitor.items.isEmpty
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static func relativeTime(from date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
