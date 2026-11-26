import Foundation
import Observation

/// Editor logic ported from the web demo: ordered items, validate-and-commit before
/// switching kind, tap to edit in place, multi-select delete with undo.
@MainActor
@Observable
final class EditorModel {
    let day: DayKey
    var items: [RecordItem]
    var kind: ItemKind
    var raw: String
    var editingID: UUID?
    /// Non-nil while choosing items to delete.
    var selection: Set<UUID>?
    var notice: String?
    var saveFailed = false
    var changed: Bool
    var lastDeleted: [(index: Int, item: RecordItem)] = []

    init(day: DayKey, items: [RecordItem], draft: Draft?) {
        self.day = day
        if let draft, draft.day == day {
            self.items = draft.items
            self.kind = draft.kind
            self.raw = draft.raw
            self.editingID = draft.editingID
            self.changed = draft.changed
        } else {
            self.items = items
            self.kind = .word
            self.raw = ""
            self.editingID = nil
            self.changed = false
        }
    }

    var draft: Draft {
        Draft(day: day, items: items, kind: kind, raw: raw, editingID: editingID, changed: changed)
    }

    /// Confirms the text in the composer. Returns false when the input is invalid
    /// (the input stays so nothing is lost).
    @discardableResult
    func commitRaw() -> Bool {
        switch ItemValidator.normalize(kind, raw) {
        case .invalid:
            notice = ItemValidator.invalidMessage(for: kind)
            return false
        case .empty:
            if let editingID {
                // Clearing an item while editing removes it.
                if let index = items.firstIndex(where: { $0.id == editingID }) {
                    lastDeleted = [(index, items.remove(at: index))]
                    changed = true
                }
                self.editingID = nil
            }
            return true
        case .value(let value):
            let item = RecordItem(id: editingID ?? UUID(), kind: kind, value: value)
            if let index = items.firstIndex(where: { $0.id == editingID }) {
                items[index] = item
            } else {
                items.append(item)
            }
            raw = ""
            editingID = nil
            changed = true
            notice = nil
            return true
        }
    }

    func setKind(_ next: ItemKind) {
        guard next != kind else { return }
        guard commitRaw() else { return }
        kind = next
        notice = nil
    }

    func edit(_ item: RecordItem) {
        if selection != nil {
            toggleSelection(item.id)
            return
        }
        guard item.id != editingID, commitRaw() else { return }
        editingID = item.id
        raw = item.value
        kind = item.kind
        notice = nil
    }

    /// 취소 in the time picker: drop the staged value and leave any edited item unchanged.
    func cancelPending() {
        raw = ""
        editingID = nil
        notice = nil
    }

    func beginSelection(with id: UUID? = nil) {
        guard commitRaw() else { return }
        selection = id.map { [$0] } ?? []
    }

    func toggleSelection(_ id: UUID) {
        guard var current = selection else { return }
        if current.contains(id) { current.remove(id) } else { current.insert(id) }
        selection = current
    }

    func deleteSelected() {
        guard let selection, !selection.isEmpty else { return }
        delete(ids: selection)
        self.selection = nil
    }

    func delete(ids: Set<UUID>) {
        lastDeleted = items.enumerated()
            .filter { ids.contains($0.element.id) }
            .map { ($0.offset, $0.element) }
        items.removeAll { ids.contains($0.id) }
        if let editingID, ids.contains(editingID) {
            self.editingID = nil
            raw = ""
        }
        changed = true
    }

    /// Puts deleted items back in their original positions.
    func undoDelete() {
        for entry in lastDeleted.sorted(by: { $0.index < $1.index }) {
            items.insert(entry.item, at: min(entry.index, items.count))
        }
        lastDeleted = []
    }

    /// Items to save, including whatever is still in the composer. Nil if the
    /// composer holds an invalid value.
    func itemsForSaving() -> [RecordItem]? {
        commitRaw() ? items : nil
    }
}
