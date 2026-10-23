import AppKit
import ApplicationServices

/// Finds where to anchor the popup: the text caret (or failing that, the
/// bottom-left of the focused field) in whatever app currently has focus,
/// using the Accessibility API. Returns AppKit screen coordinates
/// (bottom-left origin) or nil if the frontmost app doesn't expose this
/// (some web content / custom-drawn UIs don't).
enum CaretLocator {
    /// Chromium/Electron apps (Chrome, Slack, VS Code, Electron-based chat
    /// apps, etc.) often don't build their full accessibility tree unless
    /// they detect assistive tech is attached. Nudging this attribute wakes
    /// it up so kAXFocusedUIElement etc. actually work — but the rebuild is
    /// async, so the very next query can still come back empty. Call this
    /// proactively on app-activation (see AppDelegate) so it's already warm
    /// by the time the user triggers the popup, not just at show() time.
    static func wakeAccessibility(forPID pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    private static let editableTextRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField"
    ]

    /// Whether the currently focused UI element looks like an actual text
    /// input (vs. a button, list, the desktop, or nothing at all) — used to
    /// decide whether the global shortcut should do anything.
    static func isEditableTextFocused() -> Bool {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            wakeAccessibility(forPID: pid)
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else {
            return false
        }
        let element = focusedRef as! AXUIElement

        var roleRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            // Some apps (mainly Electron/web content) don't expose a role at
            // all for otherwise-legitimate text fields. Don't block on
            // uncertainty — only block when we positively know it's NOT text.
            return true
        }

        return editableTextRoles.contains(role)
    }

    static func focusedCaretBottomLeft() -> NSPoint? {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            wakeAccessibility(forPID: pid)
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else {
            return nil
        }
        let element = focusedRef as! AXUIElement

        if let rect = selectedTextBounds(of: element) {
            // A real caret/selection rect: width 0 for an empty-selection
            // caret, or the width of the actual selected text — both
            // legitimately small/precise, so a tight width cap is a good
            // "is this real data, not a bogus default" signal here.
            if rect.width >= 0, rect.height > 0, rect.width < 900, rect.height < 300 {
                return convertToAppKit(bottomLeftOf: rect)
            }
        }

        if let rect = elementFrame(of: element) {
            // A focused *field's* frame can legitimately be very wide (a
            // full-width chat composer, search bar, etc.) — height is the
            // useful signal here: reject only if it looks like the whole
            // window/webview got reported instead of an actual field.
            if rect.width > 0, rect.height > 0, rect.height < 200 {
                return convertToAppKit(bottomLeftOf: rect)
            }
        }

        return nil
    }

    private static func selectedTextBounds(of element: AXUIElement) -> CGRect? {
        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef else { return nil }

        var boundsRef: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef as CFTypeRef,
            &boundsRef
        ) == .success, let boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private static func elementFrame(of element: AXUIElement) -> CGRect? {
        var positionRef: AnyObject?
        var sizeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    /// AX coordinates are global, top-left origin. AppKit screens are
    /// bottom-left origin, flipped relative to the primary screen's height.
    private static func convertToAppKit(bottomLeftOf axRect: CGRect) -> NSPoint? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let axBottomY = axRect.origin.y + axRect.height
        let appKitY = primaryHeight - axBottomY
        return NSPoint(x: axRect.origin.x, y: appKitY)
    }
}
