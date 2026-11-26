import CoreGraphics

/// 기록한 날 bento rows (Figma 289-16838, shared with Android).
/// Cards are as wide as their content (wrapped to the available width if needed). Two adjacent
/// single-line cards of the same height share a row when both fit; a wrapped card has a row of
/// its own. Left-over width of at least gap + 24 becomes an empty bento; otherwise it is split
/// equally among the row's cards (their content shifts toward the trailing edge). Empty bentos
/// alternate right → left, counting only rows that actually have one.
enum BentoRows {
    static let gap: CGFloat = 8
    static let minBento: CGFloat = 24
    /// Narrowest a date card gets (shared with Android).
    static let minCard: CGFloat = 67

    struct Card: Equatable {
        /// Width the content needs at the available width (widest line when wrapped).
        var width: CGFloat
        var height: CGFloat
        /// More than one line at the available width.
        var wraps: Bool
    }

    enum Side: Equatable { case leading, trailing }

    struct Row: Equatable {
        /// Card indexes, left to right in reading order.
        var cards: [Int]
        /// Final card widths, same order as `cards`.
        var widths: [CGFloat]
        var height: CGFloat
        /// Width and side of the empty bento, if this row has one.
        var bento: (side: Side, width: CGFloat)?

        static func == (a: Row, b: Row) -> Bool {
            a.cards == b.cards && a.widths == b.widths && a.height == b.height
                && a.bento?.side == b.bento?.side && a.bento?.width == b.bento?.width
        }
    }

    static func rows(_ cards: [Card], available: CGFloat) -> [Row] {
        var rows: [Row] = []
        var nextSide: Side = .trailing
        var index = 0
        while index < cards.count {
            var members = [index]
            let card = cards[index]
            if !card.wraps, index + 1 < cards.count {
                let next = cards[index + 1]
                if !next.wraps, next.height == card.height,
                   max(card.width, minCard) + gap + max(next.width, minCard) <= available {
                    members.append(index + 1)
                }
            }
            var widths = members.map { min(max(cards[$0].width, minCard), available) }
            let used = widths.reduce(0, +) + gap * CGFloat(members.count - 1)
            let leftover = available - used
            var bento: (Side, CGFloat)?
            if leftover >= gap + minBento {
                bento = (nextSide, leftover - gap)
                nextSide = nextSide == .trailing ? .leading : .trailing
            } else if leftover > 0 {
                let share = leftover / CGFloat(widths.count)
                widths = widths.map { $0 + share }
            }
            rows.append(Row(cards: members, widths: widths,
                            height: members.map { cards[$0].height }.max() ?? 0, bento: bento))
            index += members.count
        }
        return rows
    }
}
