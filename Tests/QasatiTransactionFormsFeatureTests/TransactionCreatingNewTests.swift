import Foundation
import XCTest
@testable import QasatiDomain

/// اختبارات مباشرة لـ `Transaction.creatingNew` (المُضافة في Phase 5). عمدًا داخل هذا
/// الهدف غير المحمي (QasatiTransactionFormsFeatureTests) وليس داخل Tests/QasatiDomainTests
/// المحمي — الموافقة في Phase 5 شملت تعديل Transaction.swift نفسه فقط، وليس إضافة ملفات
/// جديدة إلى هدف اختبارات Phase 1 المحمي.
final class TransactionCreatingNewTests: XCTestCase {

    func test_creatingNew_generatesIDWithExpectedPrefixAndShape() {
        let t = Transaction.creatingNew(type: .deposit, amount: 1000, note: "")

        XCTAssertTrue(t.id.hasPrefix("tx_"))
        let parts = t.id.split(separator: "_")
        XCTAssertEqual(parts.count, 3) // "tx", الجزء الزمني بالأساس36، الجزء العشوائي بالأساس36
    }

    func test_creatingNew_setsDateISOToNow() {
        let before = Date()
        let t = Transaction.creatingNew(type: .deposit, amount: 1000, note: "")
        let after = Date()

        XCTAssertTrue(t.dateISO >= before && t.dateISO <= after)
    }

    func test_creatingNew_generatesDistinctIDsAndSeqAcrossCalls() {
        let t1 = Transaction.creatingNew(type: .deposit, amount: 1000, note: "")
        let t2 = Transaction.creatingNew(type: .deposit, amount: 1000, note: "")

        XCTAssertNotEqual(t1.id, t2.id)
        XCTAssertNotEqual(t1.seq, t2.seq)
    }

    func test_creatingNew_preservesTypeAmountNoteExactly() {
        let t = Transaction.creatingNew(type: .withdraw, amount: 42_000, note: "ملاحظة")

        XCTAssertEqual(t.type, .withdraw)
        XCTAssertEqual(t.amount, 42_000)
        XCTAssertEqual(t.note, "ملاحظة")
    }

    func test_creatingNew_seqIsCloseToDateISOInMilliseconds() {
        let t = Transaction.creatingNew(type: .deposit, amount: 1000, note: "")
        let expectedMillisFloor = t.dateISO.timeIntervalSince1970 * 1000

        // seq = نفس اللحظة بالمللي ثانية + كسر عشوائي في [0,1)
        XCTAssertGreaterThanOrEqual(t.seq, expectedMillisFloor)
        XCTAssertEqual(t.seq, expectedMillisFloor, accuracy: 1.0)
    }
}
