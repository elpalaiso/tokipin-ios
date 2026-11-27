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
    /// Derived from `records`, kept in step on every write so views never scan all days per
    /// frame: days per month (newest first), recorded months and years, earliest day.
    private(set) var monthIndex: [MonthKey: [DayKey]] = [:]
    private(set) var recordedMonths: Set<MonthKey> = []
    private(set) var recordedYears: Set<Int> = []
    private(set) var earliestDay: DayKey?
    /// Lower-cased search text, built on the first search after a change.
    @ObservationIgnored private var searchIndex: [(day: DayKey, item: RecordItem, text: NSString, date: NSString, label: NSString)]?
    @ObservationIgnored private var searchIndexLocale = ""
    /// Encoded JSON per saved day (see `write`).
    @ObservationIgnored private var dayJSON: [DayKey: Data] = [:]
    /// Bumped on every write so a background cache fill never lands on newer data.
    @ObservationIgnored private var recordsVersion = 0
    /// Unsaved editor state, one per day, so a draft on one day never overwrites another's.
    private(set) var drafts: [DayKey: Draft] = [:]
    /// True until a saved record is loaded or the first real editor is available to use.
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
    private var draftURL: URL { directory.appendingPathComponent("draft.json") }   // v0.1 single draft
    private var draftsURL: URL { directory.appendingPathComponent("drafts.json") }

    // MARK: Loading

    func load() async {
        state = .loading
        let recordsURL = recordsURL
        let draftURL = draftURL
        let draftsURL = draftsURL
        let result: Result<(RecordArchive?, [Draft]), Error> = await Task.detached(priority: .userInitiated) {
            do {
                var archive: RecordArchive?
                if FileManager.default.fileExists(atPath: recordsURL.path) {
                    let data = try Data(contentsOf: recordsURL)
                    archive = try JSONDecoder.tokipin.decode(RecordArchive.self, from: data)
                }
                // A broken draft must never block reading the records.
                var drafts = (try? Data(contentsOf: draftsURL)).flatMap { try? JSONDecoder.tokipin.decode([Draft].self, from: $0) } ?? []
                if drafts.isEmpty, let old = (try? Data(contentsOf: draftURL)).flatMap({ try? JSONDecoder.tokipin.decode(Draft.self, from: $0) }) {
                    drafts = [old]
                }
                return .success((archive, drafts))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let (archive, drafts)):
            var records: [DayKey: [RecordItem]] = [:]
            var updated: [DayKey: Date] = [:]
            for day in archive?.days ?? [] where !day.items.isEmpty {
                records[day.date] = day.items
                updated[day.date] = day.updatedAt
            }
            self.records = records
            self.updatedAt = updated
            reindex()
            primeDayJSON()
            // A draft identical to what is saved holds nothing to resume.
            self.drafts = Dictionary(drafts.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
                .filter { day, draft in !(draft.raw.isEmpty && draft.items == (records[day] ?? [])) }
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

    func needsSampleCalendar(hasUsageChoice: Bool) -> Bool {
        state == .loaded && isFirstLaunch && records.isEmpty && drafts.isEmpty
            && !hasUsageChoice && !defaults.bool(forKey: "tokipin.completedSampleCalendar")
    }

    func completeSampleCalendar() {
        defaults.set(true, forKey: "tokipin.completedSampleCalendar")
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
        try write(next, updated: nextUpdated, changed: [day])
        records = next
        updatedAt = nextUpdated
        reindex(month: day.monthKey)
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

    /// Fills the per-day JSON cache off the main thread after loading, so even the first save
    /// re-encodes only the day that changed.
    private func primeDayJSON() {
        let snapshot = records, updated = updatedAt, version = recordsVersion
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder.tokipinCompact
            var cache: [DayKey: Data] = [:]
            for (day, items) in snapshot {
                cache[day] = try? encoder.encode(RecordArchive.Day(date: day, items: items, updatedAt: updated[day] ?? Date()))
            }
            await MainActor.run { [cache] in
                if self.recordsVersion == version && self.dayJSON.isEmpty { self.dayJSON = cache }
            }
        }
    }

    // MARK: Index

    /// Full rebuild (load, import, replace).
    private func reindex() {
        var index: [MonthKey: [DayKey]] = [:]
        for day in records.keys { index[day.monthKey, default: []].append(day) }
        for key in index.keys { index[key]!.sort(by: >) }
        monthIndex = index
        recordedMonths = Set(index.keys)
        recordedYears = Set(index.keys.map(\.year))
        earliestDay = records.keys.min()
        searchIndex = nil
    }

    /// One month changed (a day saved or removed).
    private func reindex(month: MonthKey) {
        let days = records.keys.filter { $0.monthKey == month }.sorted(by: >)
        monthIndex[month] = days.isEmpty ? nil : days
        if days.isEmpty { recordedMonths.remove(month) } else { recordedMonths.insert(month) }
        recordedYears = Set(recordedMonths.map(\.year))
        earliestDay = monthIndex[recordedMonths.min() ?? month]?.last
        searchIndex = nil
    }

    /// Writes the whole archive atomically. Each day's JSON is cached, so saving one day
    /// re-encodes only that day (`changed`; nil = everything) and joins the rest.
    private func write(_ records: [DayKey: [RecordItem]], updated: [DayKey: Date], changed: Set<DayKey>?) throws {
        if simulateWriteFailure { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var cache = changed == nil ? [:] : dayJSON
        let encoder = JSONEncoder.tokipinCompact
        var data = Data(#"{"version":1,"days":["#.utf8)
        for (index, day) in records.keys.sorted().enumerated() {
            let chunk: Data
            if let cached = cache[day], changed?.contains(day) == false {
                chunk = cached
            } else {
                chunk = try encoder.encode(RecordArchive.Day(date: day, items: records[day]!, updatedAt: updated[day] ?? Date()))
                cache[day] = chunk
            }
            if index > 0 { data.append(UInt8(ascii: ",")) }
            data.append(chunk)
        }
        data.append(contentsOf: Array("]}".utf8))
        try data.write(to: recordsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Only after a successful write; removed days drop out of the cache.
        dayJSON = cache.filter { records[$0.key] != nil }
        recordsVersion += 1
    }

    private static func archive(_ records: [DayKey: [RecordItem]], updated: [DayKey: Date]) -> RecordArchive {
        RecordArchive(days: records.keys.sorted().map {
            .init(date: $0, items: records[$0]!, updatedAt: updated[$0] ?? Date())
        })
    }

    /// Replaces every record (debug sample data, tests). Saved atomically like any write.
    func replaceAll(with archive: RecordArchive) throws {
        guard state == .loaded else { throw StoreError.notLoaded }
        var next: [DayKey: [RecordItem]] = [:]
        var nextUpdated: [DayKey: Date] = [:]
        for day in archive.days where !day.items.isEmpty {
            next[day.date] = day.items
            nextUpdated[day.date] = day.updatedAt
        }
        try write(next, updated: nextUpdated, changed: nil)
        records = next
        updatedAt = nextUpdated
        reindex()
        drafts = [:]
        writeDrafts()
    }

    // MARK: Draft

    func draft(for day: DayKey) -> Draft? { drafts[day] }

    /// The most recently touched draft (resumed after the app was interrupted).
    var latestDraft: Draft? {
        drafts.values.max { ($0.savedAt ?? .distantPast) < ($1.savedAt ?? .distantPast) }
    }

    /// Stores or clears the draft of one day; other days' drafts are untouched.
    func updateDraft(_ draft: Draft?, for day: DayKey) {
        if var draft {
            draft.savedAt = Date()
            drafts[day] = draft
        } else {
            drafts[day] = nil
        }
        writeDrafts()
    }

    private func writeDrafts() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if drafts.isEmpty {
                try? FileManager.default.removeItem(at: draftsURL)
            } else {
                let list = drafts.keys.sorted().map { drafts[$0]! }
                try JSONEncoder.tokipin.encode(list).write(to: draftsURL, options: .atomic)
            }
            try? FileManager.default.removeItem(at: draftURL)
        } catch {
            // Drafts stay in memory; losing the on-disk copy is not fatal.
        }
    }

    // MARK: Queries

    var isEmpty: Bool { records.isEmpty }

    /// Newest first.
    var sortedDays: [DayKey] { monthIndex.keys.sorted(by: >).flatMap { monthIndex[$0]! } }

    func items(on day: DayKey) -> [RecordItem] { records[day] ?? [] }

    /// Newest first, from the month index.
    func days(in month: MonthKey) -> [DayKey] { monthIndex[month] ?? [] }

    /// Matches item text, a kind name ("장소"), or a date ("11.25", "2026.11").
    func search(_ query: String, locale: Locale = TimeRules.displayLocale,
                kindLabel: (ItemKind) -> String = { $0.label }) -> [SearchResult] {
        // One case rule for the query and everything indexed: the app locale's (Turkish İ/ı included).
        let q = Self.searchForm(query.trimmingCharacters(in: .whitespaces), locale: locale)
        guard !q.isEmpty else { return [] }
        // Kind names match whatever their case on screen ("Place", "place", "Ort").
        let kind = ItemKind.allCases.first {
            kindLabel($0).compare(q, options: .caseInsensitive, range: nil, locale: locale) == .orderedSame
        }
        if searchIndex == nil || searchIndexLocale != locale.identifier {
            searchIndexLocale = locale.identifier
            let labeler = DayKey.labeler(locale: locale)
            let spoken = DayKey.formatter(template: "yMMMMdEEEE", locale: locale)
            searchIndex = sortedDays.flatMap { day in
                let date = (day.dotted + " " + day.string) as NSString
                // The date as the app shows and reads it ("Wed, 25 Nov 2026", "Wednesday 25 November 2026").
                let label = Self.searchForm(labeler(day) + "\n" + spoken.string(from: day.date), locale: locale) as NSString
                return (records[day] ?? []).map { item in
                    // Times match as stored ("18:45") and as shown ("6:45 PM").
                    let text = item.kind == .time ? item.value + "\n" + item.displayValue : item.value
                    return (day, item, Self.searchForm(text, locale: locale) as NSString, date, label)
                }
            }
        }
        var results: [SearchResult] = []
        // Dates only match queries made of digits and separators ("11.25", "2026.11").
        let datelike = q.count >= 2 && q.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
        let labelLike = q.count >= 3
        for entry in searchIndex! {
            let dateMatch = (datelike && entry.date.range(of: q, options: .literal).location != NSNotFound)
                || (labelLike && entry.label.range(of: q, options: .literal).location != NSNotFound)
            if dateMatch || entry.item.kind == kind || entry.text.range(of: q, options: .literal).location != NSNotFound {
                results.append(SearchResult(day: entry.day, item: entry.item))
            }
        }
        return results
    }

    /// Lower-cased in the app locale, with formatter spaces (narrow/no-break, thin) turned into
    /// plain spaces so a typed "6:45 PM" matches the formatted "6:45\u{202F}PM".
    static func searchForm(_ text: String, locale: Locale) -> String {
        let lowered = text.lowercased(with: locale)
        // Most strings hold none of these spaces: one scan, no copy.
        guard lowered.unicodeScalars.contains(where: isSpecialSpace) else { return lowered }
        var plain = String.UnicodeScalarView()
        plain.append(contentsOf: lowered.unicodeScalars.lazy.map { isSpecialSpace($0) ? " " : $0 })
        return String(plain)
    }

    /// Narrow no-break, no-break, thin and figure spaces that formatters put in dates and times.
    private static func isSpecialSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x202F, 0x00A0, 0x2009, 0x2007: true
        default: false
        }
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

extension JSONEncoder {
    static var tokipinCompact: JSONEncoder {
        let encoder = JSONEncoder()
        // Same ISO 8601 text as `.iso8601`, with one shared formatter instead of one per date.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFormatter.string(from: date))
        }
        return encoder
    }

    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension JSONDecoder {
    static var tokipin: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
