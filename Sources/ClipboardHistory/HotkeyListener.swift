import AppKit

/// Detects the configured global shortcut (default Cmd+Shift+V, but can also
/// be a modifier + extra mouse button, e.g. a mouse's side button) and
/// swallows it so it doesn't also trigger default behavior (a "Paste and
/// Match Style" binding, or a browser back/forward navigation on a side
/// mouse button), firing `onTrigger` instead to open the clipboard history
/// panel.
///
/// This needs a CGEventTap (not NSEvent's global monitor) because only an
/// event tap can consume/drop an event before it reaches other apps, which
/// requires the app to be trusted for Accessibility.
final class HotkeyListener {
    var shortcut: HotkeyShortcut = ShortcutStore.load()
    var onTrigger: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    static func accessibilityGranted(prompt: Bool) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Returns false if Accessibility permission is missing; caller should
    /// tell the user to grant it in System Settings and retry.
    @discardableResult
    func start() -> Bool {
        guard HotkeyListener.accessibilityGranted(prompt: true) else { return false }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.otherMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()
                return listener.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap if it thinks it's unresponsive; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let activeFlags = event.flags.intersection(HotkeyShortcut.modifierMask)
        var matched = false

        switch type {
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if case .key(let code) = shortcut.trigger, keyCode == code, activeFlags == shortcut.modifierFlags {
                matched = true
            }
        case .otherMouseDown:
            let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            if case .mouseButton(let number) = shortcut.trigger, buttonNumber == number, activeFlags == shortcut.modifierFlags {
                matched = true
            }
        default:
            break
        }

        guard matched else { return Unmanaged.passRetained(event) }

        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
        return nil // swallow it so the frontmost app doesn't also act on it
    }
}
