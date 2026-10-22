import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let date: Date

    var preview: String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ⏎ ")
        if collapsed.count > 80 {
            return String(collapsed.prefix(80)) + "…"
        }
        return collapsed
    }
}
