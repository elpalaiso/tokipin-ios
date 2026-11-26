import Foundation

/// The four kinds of entries a record can hold. Order matches the input toolbar.
enum ItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case word, emoji, place, time

    var id: String { rawValue }

    var label: String {
        switch self {
        case .word: String(localized: "kind.word", defaultValue: "단어")
        case .emoji: String(localized: "kind.emoji", defaultValue: "이모지")
        case .place: String(localized: "kind.place", defaultValue: "장소")
        case .time: String(localized: "kind.time", defaultValue: "시간")
        }
    }

    /// Asset catalog name of the pictogram.
    var iconName: String {
        switch self {
        case .word: "KindWord"
        case .emoji: "KindEmoji"
        case .place: "KindPlace"
        case .time: "KindTime"
        }
    }
}

struct RecordItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: ItemKind
    var value: String

    init(id: UUID = UUID(), kind: ItemKind, value: String) {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

/// Unsaved editor state. Kept on disk so an interrupted session can resume.
struct Draft: Codable, Equatable, Sendable {
    var day: DayKey
    var items: [RecordItem]
    var kind: ItemKind
    var raw: String
    var editingID: UUID?
    var changed: Bool
    /// When this draft was last written; the newest one is resumed after a relaunch.
    var savedAt: Date?
}

/// Same rules as the web demo's `normalized()`:
/// empty → nothing to add, invalid → keep the input and show a notice.
enum ItemValidator {
    enum Result: Equatable {
        case empty
        case invalid
        case value(String)
    }

    static func normalize(_ kind: ItemKind, _ raw: String) -> Result {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .empty }
        switch kind {
        case .time:
            return isTime(value) ? .value(value) : .invalid
        case .emoji:
            // Mixed input keeps only its emoji, in order ("비☕" → "☕").
            let emoji = EmojiRules.filter(value)
            return emoji.isEmpty ? .invalid : .value(emoji)
        case .word, .place:
            return .value(value)
        }
    }

    static func isTime(_ value: String) -> Bool {
        value.range(of: #"^([01]\d|2[0-3]):[0-5]\d$"#, options: .regularExpression) != nil
    }

    static func invalidMessage(for kind: ItemKind) -> String {
        kind == .time ? String(localized: "시간을 선택해 주세요.") : String(localized: "이모지를 입력해 주세요.")
    }
}
