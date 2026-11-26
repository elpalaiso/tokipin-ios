import Foundation

/// Picking another date in the editor (Calendar Range handoff). The picker's confirm only
/// moves the editor to the new date; nothing is saved until the editor's ✓.
enum EntryDateChange {
    struct Outcome: Equatable {
        /// Draft to keep on the day being left (nil: none needed).
        var sourceDraft: Draft?
        /// Draft the editor opens with on the new day (nil: its saved items as they are).
        var targetDraft: Draft?
    }

    /// - Parameters:
    ///   - current: the editor's state on the day being left (an item being edited is already committed).
    ///   - saved: that day's saved items.
    ///   - wholeDay: the saved day was opened for editing (pencil). Its changes stay there as a
    ///     draft and the new day opens as it is. Otherwise only the new pieces (and the text being
    ///     typed) travel, appended after the new day's own items without duplicates.
    static func change(current: Draft, saved: [RecordItem], to target: DayKey,
                       targetSaved: [RecordItem], targetDraft: Draft?, wholeDay: Bool) -> Outcome {
        if wholeDay {
            let keep = current.items != saved || !current.raw.isEmpty
            return Outcome(sourceDraft: keep ? withChanged(current) : nil, targetDraft: targetDraft)
        }

        let savedIDs = Set(saved.map(\.id))
        let newItems = current.items.filter { !savedIDs.contains($0.id) }
        let kept = current.items.filter { savedIDs.contains($0.id) }
        let source = kept != saved
            ? Draft(day: current.day, items: kept, kind: current.kind, raw: "", editingID: nil, changed: true)
            : nil

        guard !newItems.isEmpty || !current.raw.isEmpty else {
            return Outcome(sourceDraft: source, targetDraft: targetDraft)
        }
        // The new day's own state is never overwritten: its draft (or saved items) comes first.
        let base = targetDraft?.items ?? targetSaved
        let present = Set(base.map(\.id))
        let items = base + newItems.filter { !present.contains($0.id) }
        let target = Draft(day: target, items: items, kind: current.kind, raw: current.raw,
                           editingID: nil, changed: items != targetSaved || targetDraft?.changed == true)
        return Outcome(sourceDraft: source, targetDraft: target)
    }

    private static func withChanged(_ draft: Draft) -> Draft {
        var draft = draft
        draft.changed = true
        draft.editingID = nil
        return draft
    }
}
