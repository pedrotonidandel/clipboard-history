import Carbon.HIToolbox.Events
import CoreGraphics

enum ShortcutTrigger: Equatable {
    case key(Int64)
    case mouseButton(Int)
}

struct HotkeyShortcut: Equatable {
    var trigger: ShortcutTrigger
    /// Restricted to Cmd/Shift/Option/Control bits only.
    var modifierFlags: CGEventFlags

    static let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
    static let defaultShortcut = HotkeyShortcut(trigger: .key(Int64(kVK_ANSI_V)), modifierFlags: [.maskCommand, .maskShift])

    var isValid: Bool {
        switch trigger {
        case .key(let code):
            return !modifierFlags.isEmpty && HotkeyShortcut.keyCodeNames[code] != nil
        case .mouseButton(let number):
            return number >= 2 // 0/1 are left/right clicks — never hijack those
        }
    }

    var displayString: String {
        var parts: [String] = []
        if modifierFlags.contains(.maskControl) { parts.append("⌃") }
        if modifierFlags.contains(.maskAlternate) { parts.append("⌥") }
        if modifierFlags.contains(.maskShift) { parts.append("⇧") }
        if modifierFlags.contains(.maskCommand) { parts.append("⌘") }
        switch trigger {
        case .key(let code):
            parts.append(HotkeyShortcut.keyCodeNames[code] ?? "?")
        case .mouseButton(let number):
            parts.append(HotkeyShortcut.mouseButtonName(number))
        }
        return parts.joined()
    }

    static func mouseButtonName(_ number: Int) -> String {
        switch number {
        case 2: return "Middle Click"
        case 3: return "Mouse 4"
        case 4: return "Mouse 5"
        default: return "Mouse Button \(number + 1)"
        }
    }

    // Common ANSI key codes. Covers letters, digits, and a few extras —
    // good enough for a shortcut recorder without pulling in full
    // keyboard-layout translation (UCKeyTranslate).
    static let keyCodeNames: [Int64: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9",
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}

enum ShortcutStore {
    private static let triggerKindKey = "hotkeyTriggerKind"
    private static let triggerValueKey = "hotkeyTriggerValue"
    private static let modifiersKey = "hotkeyModifierFlags"

    static func load() -> HotkeyShortcut {
        let defaults = UserDefaults.standard
        guard let kind = defaults.string(forKey: triggerKindKey) else { return .defaultShortcut }
        let value = Int64(defaults.integer(forKey: triggerValueKey))
        let rawFlags = UInt64(defaults.integer(forKey: modifiersKey))
        let trigger: ShortcutTrigger = kind == "mouse" ? .mouseButton(Int(value)) : .key(value)
        let shortcut = HotkeyShortcut(trigger: trigger, modifierFlags: CGEventFlags(rawValue: rawFlags))
        return shortcut.isValid ? shortcut : .defaultShortcut
    }

    static func save(_ shortcut: HotkeyShortcut) {
        let defaults = UserDefaults.standard
        switch shortcut.trigger {
        case .key(let code):
            defaults.set("key", forKey: triggerKindKey)
            defaults.set(Int(code), forKey: triggerValueKey)
        case .mouseButton(let number):
            defaults.set("mouse", forKey: triggerKindKey)
            defaults.set(number, forKey: triggerValueKey)
        }
        defaults.set(Int(shortcut.modifierFlags.rawValue), forKey: modifiersKey)
    }
}
