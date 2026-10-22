import AppKit
import ApplicationServices

/// Finds where to anchor the popup: the text caret (or failing that, the
/// bottom-left of the focused field) in whatever app currently has focus,
/// using the Accessibility API. Returns AppKit screen coordinates
/// (bottom-left origin) or nil if the frontmost app doesn't expose this
/// (some web content / custom-drawn UIs don't).
enum CaretLocator {
    static func focusedCaretBottomLeft() -> NSPoint? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }
        let element = focusedRef as! AXUIElement

        if let rect = selectedTextBounds(of: element), isPlausible(rect) {
            return convertToAppKit(bottomLeftOf: rect)
        }
        if let rect = elementFrame(of: element), isPlausible(rect) {
            return convertToAppKit(bottomLeftOf: rect)
        }
        return nil
    }

    /// Electron/web apps sometimes report a focused "element" that's really
    /// the whole window or webview. A sane caret/field rect is small; reject
    /// anything suspiciously large so we fall back to the mouse location
    /// instead of anchoring off a bogus giant rect.
    private static func isPlausible(_ rect: CGRect) -> Bool {
        rect.width > 0 && rect.height > 0 && rect.width < 800 && rect.height < 200
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
