import AppKit

/// A clickable field: click it, then press a key combo (with at least one
/// modifier) or an extra mouse button (middle click, side buttons — with or
/// without modifiers) to set a new global shortcut. Escape cancels.
final class ShortcutRecorderView: NSView {
    var shortcut: HotkeyShortcut {
        didSet { needsDisplay = true }
    }
    var onRecorded: ((HotkeyShortcut) -> Void)?

    private var isRecording = false {
        didSet {
            needsDisplay = true
            updateMouseMonitor()
        }
    }
    private var mouseMonitor: Any?

    init(shortcut: HotkeyShortcut) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 180, height: 28) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press a key or mouse button…" : shortcut.displayString
        let color: NSColor = isRecording ? .controlAccentColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attrs)
        let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        // A plain click (no modifiers) on the field itself just starts
        // recording; it is not captured as the shortcut's trigger.
        guard isRecording else {
            window?.makeFirstResponder(self)
            isRecording = true
            return
        }
        super.mouseDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }

        let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(HotkeyShortcut.modifierMask)
        apply(candidate: HotkeyShortcut(trigger: .key(Int64(event.keyCode)), modifierFlags: flags))
    }

    private func updateMouseMonitor() {
        if isRecording {
            guard mouseMonitor == nil else { return }
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
                guard let self, self.isRecording else { return event }
                let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(HotkeyShortcut.modifierMask)
                self.apply(candidate: HotkeyShortcut(trigger: .mouseButton(event.buttonNumber), modifierFlags: flags))
                return nil // swallow so it doesn't also act as a real click
            }
        } else if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    private func apply(candidate: HotkeyShortcut) {
        guard candidate.isValid else {
            NSSound.beep()
            return
        }
        shortcut = candidate
        isRecording = false
        onRecorded?(candidate)
    }
}

private let kVK_Escape: Int = 53
