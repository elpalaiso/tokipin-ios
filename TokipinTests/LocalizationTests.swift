import XCTest
@testable import Tokipin

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
