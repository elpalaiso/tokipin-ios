import XCTest
@testable import Tokipin

/// Assertions on Korean copy run when the test host's app language is Korean (the default run);
/// `-testLanguage en` runs check the rest. Translations are covered per .lproj below.
var koreanHost: Bool { Bundle.main.preferredLocalizations.first == "ko" }

/// Reads the compiled catalog per language (.lproj in the app bundle), like the system does
/// for a person whose app language is set to that locale.
final class LocalizationTests: XCTestCase {
    static let languages = ["ko", "en", "ja", "de", "fr", "id", "vi", "tr", "ru", "hi", "th", "pt-BR", "es", "es-419",
                            "zh-Hans", "zh-Hant", "zh-HK"]

    private func bundle(_ language: String) throws -> Bundle {
        let app = Bundle(for: RecordStore.self)
        let path = try XCTUnwrap(app.path(forResource: language, ofType: "lproj"), "\(language).lproj missing")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func text(_ key: String, _ language: String, _ args: CVarArg...) throws -> String {
        // Korean is the source language: a key missing from ko.lproj falls back to the key itself.
        let format = try bundle(language).localizedString(forKey: key, value: language == "ko" ? key : "⚠︎", table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: args)
    }

    func testEveryLanguageIsShipped() throws {
        let shipped = Set(Bundle(for: RecordStore.self).localizations)
        for language in Self.languages { XCTAssertTrue(shipped.contains(language), language) }
    }

    func testVibrationSettingUsesWebWording() throws {
        XCTAssertEqual(try text("진동", "en"), "Vibration")
        XCTAssertEqual(try text("날짜를 넘기거나 보기를 바꿀 때 가볍게 진동해요.", "en"),
                       "Your device vibrates gently when you switch days or views.")
        for language in Self.languages where language != "ko" {
            XCTAssertNotEqual(try text("진동", language), "진동", language)
        }
    }

    func testPluralsAt0_1_2_5_21() throws {
        let key = "이날 기록 %lld개를 삭제했어요."
        XCTAssertEqual(try text(key, "en", 1), "Deleted 1 item from this day.")
        XCTAssertEqual(try text(key, "en", 2), "Deleted 2 items from this day.")
        XCTAssertEqual(try text(key, "ru", 1), "Удалён 1 элемент за этот день.")
        XCTAssertEqual(try text(key, "ru", 2), "Удалено 2 элемента за этот день.")
        XCTAssertEqual(try text(key, "ru", 5), "Удалено 5 элементов за этот день.")
        XCTAssertEqual(try text(key, "ru", 21), "Удалён 21 элемент за этот день.")
        XCTAssertEqual(try text(key, "ja", 5), "この日の記録5件を削除しました。")
        for language in Self.languages {
            for count in [0, 1, 2, 5, 21] {
                let value = try text(key, language, count)
                XCTAssertTrue(value.contains("\(count)"), "\(language) \(count): \(value)")
                XCTAssertFalse(value.contains("⚠︎") || value.contains("%"), "\(language) \(count): \(value)")
            }
        }
    }

    func testPluralWithOtherArgumentsKeepsOrder() throws {
        let key = "%@, 기록한 날 %lld일"
        XCTAssertEqual(try text(key, "en", "June 2017", 1), "June 2017, 1 day with a note")
        XCTAssertEqual(try text(key, "en", "June 2017", 3), "June 2017, 3 days with notes")
        XCTAssertEqual(try text(key, "ru", "июнь 2017", 5), "июнь 2017, 5 дней с записями")
        let fold = "%@부터 %@까지 기록 없는 %lld개월"
        XCTAssertEqual(try text(fold, "en", "June 2017", "March 2023", 70), "June 2017 to March 2023, 70 months without notes")
        XCTAssertEqual(try text(fold, "ko", "2017년 6월", "2023년 3월", 70), "2017년 6월부터 2023년 3월까지 기록 없는 70개월")
        for language in Self.languages {
            let value = try text(fold, language, "A", "B", 21)
            XCTAssertTrue(value.contains("A") && value.contains("B") && value.contains("21"), "\(language): \(value)")
        }
    }

    func testRegionalVariantsStayDistinct() throws {
        XCTAssertNotEqual(try text("저장한 기록을 JSON 파일로 내려받아요.", "zh-Hant"), try text("저장한 기록을 JSON 파일로 내려받아요.", "zh-HK"))
        XCTAssertNotEqual(try text("설정으로", "es"), try text("설정으로", "es-419"))
    }

    func testCardDateOrderFollowsTheLanguage() throws {
        XCTAssertEqual(try text("%lld / %@", "en", 26, "Thu"), "Thu 26")
        XCTAssertEqual(try text("%lld / %@", "ja", 10, "火"), "10 / 火")
        XCTAssertEqual(try text("%lld / %@", "ko", 26, "목"), "26 / 목")
    }
}

/// Review fixes for tokipin-ios#1: the app's own lookup path, search by translated names and
/// displayed dates, and the person's region in date formats.
@MainActor
final class LocalizationRuntimeTests: XCTestCase {
    /// Same path as `String(localized:)` in the app, with the app language set to `language`.
    private func resolved(_ value: String.LocalizationValue, _ language: String) -> String {
        String(localized: LocalizedStringResource(value, locale: Locale(identifier: language),
                                                  bundle: .forClass(RecordStore.self)))
    }

    func testKoreanCountsStayKoreanWithEnglishFallback() {
        let count = 2
        XCTAssertEqual(resolved("이날 기록 \(count)개를 삭제했어요.", "ko"), "이날 기록 2개를 삭제했어요.")
        XCTAssertEqual(resolved("이날 기록 \(count)개 삭제", "ko"), "이날 기록 2개 삭제")
        XCTAssertEqual(resolved("\("11월"), 기록한 날 \(count)일", "ko"), "11월, 기록한 날 2일")
        XCTAssertEqual(resolved("\("2017년 6월")부터 \("2023년 3월")까지 기록 없는 \(70)개월", "ko"),
                       "2017년 6월부터 2023년 3월까지 기록 없는 70개월")
        XCTAssertEqual(resolved("이날 기록 \(count)개를 삭제했어요.", "en"), "Deleted 2 items from this day.")
        // A language the app does not ship falls back to English.
        XCTAssertEqual(resolved("진동", "it"), "Vibration")
    }

    func testRegionShapesDates() {
        let day = DayKey(year: 2026, month: 11, day: 25)
        XCTAssertEqual(day.label(locale: TimeRules.locale(localization: "en", region: Locale.Region("US"))), "Wed, Nov 25, 2026")
        XCTAssertEqual(day.label(locale: TimeRules.locale(localization: "en", region: Locale.Region("GB"))), "Wed, 25 Nov 2026")
        // A localization with its own region keeps it.
        XCTAssertEqual(TimeRules.locale(localization: "zh-HK", region: Locale.Region("TW")).region, Locale.Region("HK"))
        XCTAssertEqual(day.label(locale: Locale(identifier: "ko")), "2026.11.25(수)")
    }

    private func store() async throws -> RecordStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.save(day: DayKey(year: 2026, month: 11, day: 25), items: [RecordItem(kind: .place, value: "Paris")])
        try store.save(day: DayKey(year: 2026, month: 11, day: 24), items: [RecordItem(kind: .word, value: "Tea")])
        return store
    }

    func testSearchByTranslatedKindName() async throws {
        let store = try await store()
        let english: (ItemKind) -> String = { ["word": "Word", "emoji": "Emoji", "place": "Place", "time": "Time"][$0.rawValue]! }
        let german: (ItemKind) -> String = { ["word": "Wort", "emoji": "Emoji", "place": "Ort", "time": "Uhrzeit"][$0.rawValue]! }
        let en = Locale(identifier: "en_US"), de = Locale(identifier: "de_DE")
        XCTAssertEqual(store.search("Place", locale: en, kindLabel: english).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("place", locale: en, kindLabel: english).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("ort", locale: de, kindLabel: german).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("Paris", locale: en, kindLabel: english).count, 1)
    }

    func testSearchByDisplayedDate() async throws {
        let store = try await store()
        let en = Locale(identifier: "en_US"), gb = Locale(identifier: "en_GB")
        XCTAssertEqual(store.search("2026-11-25", locale: en).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("Wed, Nov 25, 2026", locale: en).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("Wed, 25 Nov 2026", locale: gb).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("2026.11.25(수)", locale: Locale(identifier: "ko")).map(\.item.value), ["Paris"])
        XCTAssertEqual(store.search("11.24", locale: en).map(\.item.value), ["Tea"])
    }

    func testSpokenDateAndDisplayedTime() async throws {
        let day = DayKey(year: 2026, month: 11, day: 25)
        let gb = TimeRules.locale(localization: "en", region: Locale.Region("GB"))
        XCTAssertEqual(day.spokenLabel(locale: gb), "Wednesday, 25 November 2026")
        XCTAssertEqual(day.spokenLabel(locale: Locale(identifier: "ko_KR")), "2026년 11월 25일 수요일")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.save(day: day, items: [RecordItem(kind: .time, value: "18:45")])
        let shown = RecordItem(kind: .time, value: "18:45").displayValue.lowercased()
        XCTAssertEqual(store.search(shown, locale: gb).count, 1, shown)
        // The formatter puts U+202F before AM/PM; typing a plain space must match too.
        let us = TimeRules.locale(localization: "en", region: Locale.Region("US"))
        let copied = TimeRules.display("18:45", uses24Hour: false)
        XCTAssertEqual(store.search(copied, locale: us).count, 1, copied)
        if copied.contains("PM") || copied.contains("pm") {
            XCTAssertEqual(store.search("6:45 PM", locale: us).count, 1)
            XCTAssertEqual(store.search("6:45 pm", locale: us).count, 1)
        }
        XCTAssertEqual(RecordStore.searchForm("6:45\u{202F}PM", locale: us), "6:45 pm")
        XCTAssertEqual(store.search("18:45", locale: gb).count, 1)
        XCTAssertEqual(store.search("Wednesday, 25 November", locale: gb).count, 1)
    }

    func testTurkishCaseRules() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecordStore(directory: dir, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await store.load()
        try store.save(day: DayKey(year: 2026, month: 11, day: 25), items: [RecordItem(kind: .place, value: "İstanbul"),
                                                                           RecordItem(kind: .word, value: "Çay")])
        let tr = Locale(identifier: "tr_TR")
        let turkish: (ItemKind) -> String = { ["word": "Kelime", "emoji": "Emoji", "place": "Yer", "time": "Saat"][$0.rawValue]! }
        XCTAssertEqual(store.search("İstanbul", locale: tr, kindLabel: turkish).map(\.item.value), ["İstanbul"])
        XCTAssertEqual(store.search("istanbul", locale: tr, kindLabel: turkish).map(\.item.value), ["İstanbul"])
        XCTAssertEqual(store.search("İSTANBUL", locale: tr, kindLabel: turkish).map(\.item.value), ["İstanbul"])
        XCTAssertEqual(store.search("Kelime", locale: tr, kindLabel: turkish).map(\.item.value), ["Çay"])
        XCTAssertEqual(store.search("KELİME", locale: tr, kindLabel: turkish).map(\.item.value), ["Çay"])
    }

    func testThaiDeleteWordingNamesTheChosenDay() {
        let format = Bundle(path: Bundle(for: RecordStore.self).path(forResource: "th", ofType: "lproj")!)!
            .localizedString(forKey: "이날 기록 %lld개 삭제", value: nil, table: nil)
        XCTAssertFalse(format.contains("วันนี้"), format)
    }
}
