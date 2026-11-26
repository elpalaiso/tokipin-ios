import Foundation
import Observation

/// On-disk format, also used for JSON export (see README "Data format").
struct RecordArchive: Codable, Sendable {
    struct Day: Codable, Sendable {
        var date: DayKey
        var items: [RecordItem]
        var updatedAt: Date
    }

    var version: Int = 1
    var days: [Day]
}

struct SearchResult: Identifiable, Hashable {
    let day: DayKey
    let item: RecordItem
    var id: String { day.string + item.id.uuidString }
}

enum StoreError: Error {
    case notLoaded
}

/// Owns every saved record and the single in-progress draft.
/// Records live in Application Support as JSON; writes are atomic so a failed
/// write never replaces the previous file.
@MainActor
@Observable
final class RecordStore {
    enum LoadState: Equatable { case idle, loading, loaded, failed }

    private(set) var state: LoadState = .idle
    private(set) var records: [DayKey: [RecordItem]] = [:]
    private(set) var updatedAt: [DayKey: Date] = [:]
    private(set) var draft: Draft?
    /// True until the first record is saved or the first editor is closed.
    private(set) var isFirstLaunch: Bool

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let firstLaunchKey = "tokipin.hasOpenedEditor"
    /// Tests use this to simulate a full disk.
    @ObservationIgnored var simulateWriteFailure = false

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tokipin", isDirectory: true)
        self.defaults = defaults
        self.isFirstLaunch = !defaults.bool(forKey: firstLaunchKey)
    }

    private var recordsURL: URL { directory.appendingPathComponent("records.json") }
    private var draftURL: URL { directory.appendingPathComponent("draft.json") }

    // MARK: Loading

    func load() async {
        state = .loading
        let recordsURL = recordsURL
        let draftURL = draftURL
        let result: Result<(RecordArchive?, Draft?), Error> = await Task.detached(priority: .userInitiated) {
            do {
                var archive: RecordArchive?
                if FileManager.default.fileExists(atPath: recordsURL.path) {
                    let data = try Data(contentsOf: recordsURL)
                    archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: data)
                }
                // A broken draft must never block reading the records.
                let draft = (try? Data(contentsOf: draftURL)).flatMap { try? JSONDecoder.tokipin.decode(Draft.self, from: $0) }
                return .success((archive, draft))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let (archive, draft)):
            var records: [DayKey: [RecordItem]] = [:]
            var updated: [DayKey: Date] = [:]
            for day in archive?.days ?? [] where !day.items.isEmpty {
                records[day.date] = day.items
                updated[day.date] = day.updatedAt
            }
            self.records = records
            self.updatedAt = updated
            self.draft = draft
            if !records.isEmpty { markEditorOpened() }
            state = .loaded
        case .failure:
            state = .failed
        }
    }

    func markEditorOpened() {
        guard isFirstLaunch else { return }
        isFirstLaunch = false
        defaults.set(true, forKey: firstLaunchKey)
    }

    // MARK: Writing

    /// Saves the full item list for a day. An empty list removes the day.
    func save(day: DayKey, items: [RecordItem]) throws {
        guard state == .loaded else { throw StoreError.notLoaded }
        var next = records
        var nextUpdated = updatedAt
        if items.isEmpty {
            next[day] = nil
            nextUpdated[day] = nil
        } else {
            next[day] = items
            nextUpdated[day] = Date()
        }
        try write(next, updated: nextUpdated)
        records = next
        updatedAt = nextUpdated
    }

    @discardableResult
    func deleteItem(_ id: UUID, on day: DayKey) throws -> (index: Int, item: RecordItem)? {
        guard var items = records[day], let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let item = items.remove(at: index)
        try save(day: day, items: items)
        return (index, item)
    }

    func restoreItem(_ item: RecordItem, at index: Int, on day: DayKey) throws {
        var items = records[day] ?? []
        items.insert(item, at: min(index, items.count))
        try save(day: day, items: items)
    }

    func replaceItem(_ item: RecordItem, on day: DayKey) throws {
        guard var items = records[day], let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        try save(day: day, items: items)
    }

    @discardableResult
    func deleteDay(_ day: DayKey) throws -> [RecordItem] {
        let items = records[day] ?? []
        try save(day: day, items: [])
        return items
    }

    func restoreDay(_ day: DayKey, items: [RecordItem]) throws {
        try save(day: day, items: items)
    }

    private func write(_ records: [DayKey: [RecordItem]], updated: [DayKey: Date]) throws {
        if simulateWriteFailure { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.tokipin.encode(Self.archive(records, updated: updated))
        try data.write(to: recordsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func archive(_ records: [DayKey: [RecordItem]], updated: [DayKey: Date]) -> RecordArchive {
        RecordArchive(days: records.keys.sorted().map {
            .init(date: $0, items: records[$0]!, updatedAt: updated[$0] ?? Date())
        })
    }

    // MARK: Draft

    func updateDraft(_ draft: Draft?) {
        self.draft = draft
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let draft {
                try JSONEncoder.tokipin.encode(draft).write(to: draftURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: draftURL.path) {
                try FileManager.default.removeItem(at: draftURL)
            }
        } catch {
            // The draft stays in memory; losing the on-disk copy is not fatal.
        }
    }

    // MARK: Queries

    var isEmpty: Bool { records.isEmpty }

    /// Newest first.
    var sortedDays: [DayKey] { records.keys.sorted(by: >) }

    func items(on day: DayKey) -> [RecordItem] { records[day] ?? [] }

    func days(in month: MonthKey) -> [DayKey] {
        records.keys.filter { $0.monthKey == month }.sorted(by: >)
    }

    /// Matches item text, a kind name ("장소"), or a date ("11.25", "2026.11").
    func search(_ query: String) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let kind = ItemKind.allCases.first { $0.label == q }
        var results: [SearchResult] = []
        for day in sortedDays {
            let dateMatch = q.count >= 2 && (day.dotted.contains(q) || day.string.contains(q))
            for item in records[day] ?? [] {
                if dateMatch || item.kind == kind || item.value.lowercased().contains(q) {
                    results.append(SearchResult(day: day, item: item))
                }
            }
        }
        return results
    }

    func exportData() throws -> Data {
        try JSONEncoder.tokipin.encode(Self.archive(records, updated: updatedAt))
    }
}

extension JSONEncoder {
    static var tokipin: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var tokipin: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
