import XCTest
@testable import Tokipin

@MainActor
final class UsageAnalyticsTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    private var enabledCalls: [Bool] = []
    private var saves = 0

    private func make(available: Bool = true) -> UsageAnalytics {
        UsageAnalytics(directory: directory, client: UsageAnalyticsClient(
            available: available, setEnabled: { self.enabledCalls.append($0) }, recordSave: { self.saves += 1 }))
    }

    func testFirstOfferAndInterruptedLaunchRemainOff() throws {
        let first = make()
        XCTAssertFalse(first.isEnabled)
        XCTAssertTrue(first.claimInvitation())
        XCTAssertFalse(first.claimInvitation())
        first.didSaveRecord()

        let interrupted = make()
        XCTAssertFalse(interrupted.claimInvitation())
        XCTAssertFalse(interrupted.isEnabled)
        interrupted.didSaveRecord()
        XCTAssertTrue(enabledCalls.isEmpty)
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testManualSaveEligibilityExcludesDeleteOnlyAndNoChange() {
        let a = RecordItem(kind: .word, value: "A")
        let b = RecordItem(kind: .word, value: "B")
        let c = RecordItem(kind: .time, value: "18:45")
        let changed = RecordItem(id: a.id, kind: .word, value: "Edited")
        let old = [a, b, c]
        XCTAssertFalse(EditorModel.isCountedSave(previous: old, saved: old))
        XCTAssertFalse(EditorModel.isCountedSave(previous: old, saved: []))
        XCTAssertFalse(EditorModel.isCountedSave(previous: old, saved: [a, c]))
        XCTAssertTrue(EditorModel.isCountedSave(previous: [], saved: [a]))
        XCTAssertTrue(EditorModel.isCountedSave(previous: old, saved: [c, a]))
        XCTAssertTrue(EditorModel.isCountedSave(previous: old, saved: [changed, c]))
        XCTAssertTrue(EditorModel.isCountedSave(previous: [a, b], saved: [a, c]))
    }

    func testSettingsChangesAreImmediateAndSurviveLaunch() {
        let usage = make()
        XCTAssertTrue(usage.claimInvitation())
        usage.didSaveRecord()
        usage.setEnabled(true)
        usage.setEnabled(true)
        usage.didSaveRecord()
        XCTAssertEqual(enabledCalls, [true])
        XCTAssertEqual(saves, 1)

        let reopened = make()
        XCTAssertTrue(reopened.isEnabled)
        XCTAssertFalse(reopened.claimInvitation())
        reopened.setEnabled(false)
        reopened.didSaveRecord()
        XCTAssertFalse(make().isEnabled)
        XCTAssertFalse(make().claimInvitation())
        XCTAssertEqual(enabledCalls, [true, true, false])
        XCTAssertEqual(saves, 1)
        reopened.setEnabled(true)
        reopened.didSaveRecord()
        XCTAssertEqual(saves, 2)
    }

    func testMissingConfigurationDoesNotClaimOfferOrCollect() {
        let unavailable = make(available: false)
        XCTAssertFalse(unavailable.claimInvitation())
        unavailable.setEnabled(true)
        unavailable.didSaveRecord()
        XCTAssertFalse(unavailable.isEnabled)
        XCTAssertTrue(enabledCalls.isEmpty)
        XCTAssertEqual(saves, 0)
        XCTAssertTrue(make().claimInvitation())
    }
}
