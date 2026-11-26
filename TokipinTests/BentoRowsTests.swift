import XCTest
@testable import Tokipin

/// 기록한 날 bento rows (Figma 289-16838), same rule as Android.
final class BentoRowsTests: XCTestCase {
    private func card(_ width: CGFloat, wraps: Bool = false) -> BentoRows.Card {
        .init(width: width, height: wraps ? 90 : 66, wraps: wraps)
    }

    func testSingleCardLeavesBentoAlternatingFromTheRight() {
        let rows = BentoRows.rows([card(250), card(200), card(300)], available: 362)
        XCTAssertEqual(rows.map(\.cards), [[0], [1], [2]])
        XCTAssertEqual(rows[0].bento?.side, .trailing)
        XCTAssertEqual(rows[0].bento?.width, 362 - 250 - 8)
        XCTAssertEqual(rows[1].bento?.side, .leading)
        XCTAssertEqual(rows[2].bento?.side, .trailing)
    }

    func testPairWhenBothSingleLineAndFit() {
        let rows = BentoRows.rows([card(150), card(120), card(340)], available: 362)
        XCTAssertEqual(rows[0].cards, [0, 1])
        XCTAssertEqual(rows[0].bento?.width, 362 - 150 - 120 - 16)
        // 340 leaves 22: no bento, the card fills the row and the side does not flip.
        XCTAssertNil(rows[1].bento)
        XCTAssertEqual(rows[1].widths, [362])
    }

    func testNoBentoSplitsLeftoverEqually() {
        let rows = BentoRows.rows([card(170), card(170)], available: 362)
        XCTAssertNil(rows[0].bento)
        XCTAssertEqual(rows[0].widths, [177, 177])
    }

    func testWrappedCardHasItsOwnRowAndMinimumWidth() {
        let rows = BentoRows.rows([card(30), card(240, wraps: true), card(100)], available: 403)
        XCTAssertEqual(rows.map(\.cards), [[0], [1], [2]])
        XCTAssertEqual(rows[0].widths, [BentoRows.minCard])
        XCTAssertEqual(rows[1].bento?.width, 403 - 240 - 8)
        XCTAssertEqual(rows[1].height, 90)
    }

    func testOnlyRowsWithABentoFlipTheSide() {
        let rows = BentoRows.rows([card(200), card(362), card(200)], available: 362)
        XCTAssertEqual(rows[0].bento?.side, .trailing)
        XCTAssertNil(rows[1].bento)
        XCTAssertEqual(rows[2].bento?.side, .leading)
    }
}
