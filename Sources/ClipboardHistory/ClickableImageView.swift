import AppKit

/// An NSImageView that opens a URL when clicked, with a pointing-hand
/// cursor to signal it's a link.
final class ClickableImageView: NSImageView {
    var url: URL?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let url else {
            super.mouseDown(with: event)
            return
        }
        NSWorkspace.shared.open(url)
    }
}
