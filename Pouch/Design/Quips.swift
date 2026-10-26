import Foundation

/// Little lines for the empty shelf. One per day, so it changes without
/// flickering every time the shelf empties.
enum Quips {
    static let empty = [
        "Feed me files.",
        "Drop it like it's hot.",
        "I'm all ears. Well, all pouch.",
        "Nothing in here but lint.",
        "Pockets are for amateurs.",
        "Screenshots welcome. Snacks too.",
        "Empty pouch, full potential.",
        "Bring me your PNGs.",
    ]

    static let hungry = "Om nom…"

    static func ofTheDay(_ date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return empty[day % empty.count]
    }
}
