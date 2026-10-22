import AppKit

/// Polls the general pasteboard for changes and keeps the last N unique
/// plain-text copies, most recent first. Polling is the only portable way
/// to observe pasteboard changes on macOS (there is no change notification API).
final class ClipboardMonitor {
    private(set) var items: [ClipboardItem] = []
    var onChange: (() -> Void)?

    private let maxItems: Int
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    /// Guards against re-capturing the string we just wrote back to the
    /// pasteboard ourselves when the user selects a history item.
    private var ignoreNextChangeFor: String?

    init(maxItems: Int = 10) {
        self.maxItems = maxItems
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call right before programmatically writing a value back to the
    /// pasteboard so the poll loop doesn't re-add it as a "new" copy.
    func suppressNextCapture(of text: String) {
        ignoreNextChangeFor = text
    }

    func clear() {
        items.removeAll()
        onChange?()
    }

    private func pollOnce() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }

        if ignoreNextChangeFor == text {
            ignoreNextChangeFor = nil
            return
        }

        items.removeAll { $0.text == text }
        items.insert(ClipboardItem(text: text, date: Date()), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        onChange?()
    }
}
