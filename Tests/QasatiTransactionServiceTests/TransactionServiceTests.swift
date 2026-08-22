import Foundation
import XCTest
import SwiftData
@testable import QasatiTransactionService
@testable import QasatiPersistence
@testable import QasatiDomain

final class TransactionServiceTests: XCTestCase {

    // نفس نمط العزل المُستخدَم في QasatiPersistenceTests: ملف تخزين حقيقي فريد لكل اختبار
    // (وليس in-memory)، لأن اختبارات "إعادة التحميل من container جديد" تحتاج ملفًا فعليًا
    // مشتركًا على القرص لتكون تحققًا حقيقيًا، لا اعتمادًا على ذاكرة الكائن نفسه.
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QasatiTransactionServiceTests-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    override func tearDownWithError() throws {
        if let storeURL, FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        storeURL = nil
        try super.tearDownWithError()
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([PersistedTransaction.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// كل استدعاء يُنشئ container/context جديدين تمامًا يشيران لنفس ملف storeURL —
    /// استدعاؤها أكثر من مرة داخل اختبار واحد هو بالضبط أسلوب "محاكاة إعادة التشغيل".
    private func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    private func tx(
        id: String,
        type: TransactionType,
        amount: Int,
        note: String = "",
        dateISOString: String,
        seq: Double
    ) -> Transaction {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateISOString) else {
            fatalError("تاريخ اختبار غير صالح: \(dateISOString)")
        }
        return Transaction(id: id, type: type, amount: amount, note: note, dateISO: date, seq: seq)
    }

    // Result<Void, TransactionServiceError> غير Equatable (Void ليس Equatable)،
    // لذا نستخدم هذين المساعدين بدل XCTAssertEqual المباشر على النتيجة الكاملة.
    private func assertSuccess(
        _ result: Result<Void, TransactionServiceError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .failure(let error) = result {
            XCTFail("توقعت نجاحًا، لكن فشلت العملية بالخطأ: \(error)", file: file, line: line)
        }
    }

    private func assertFailure(
        _ result: Result<Void, TransactionServiceError>,
        expected: TransactionServiceError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("توقعت فشلًا بالخطأ \(expected)، لكن العملية نجحت", file: file, line: line)
        case .failure(let error):
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }

    // MARK: - 1) إضافة عملية صالحة -> محفوظة فعليًا

    func test_add_validTransaction_isPersisted() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)

        assertSuccess(try TransactionService.add(deposit, in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all, [deposit])
    }

    // MARK: - 2) إضافة عدة عمليات -> جميعها قابلة للاسترجاع

    func test_add_multipleTransactions_allRetrievable() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)

        assertSuccess(try TransactionService.add(t1, in: context))
        assertSuccess(try TransactionService.add(t2, in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(Set(all.map(\.id)), Set([t1.id, t2.id]))
    }

    // MARK: - 3) تعديل عملية موجودة -> القيمة المحفوظة تتغيّر بشكل صحيح

    func test_edit_existingTransaction_updatesPersistedValue() throws {
        let context = try makeContext()
        let original = tx(id: "t1", type: .deposit, amount: 500_000, note: "قديم", dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(original, in: context))

        assertSuccess(try TransactionService.edit(id: "t1", newAmount: 600_000, newNote: "جديد", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "t1")
        XCTAssertEqual(all.first?.amount, 600_000)
        XCTAssertEqual(all.first?.note, "جديد")
        XCTAssertEqual(all.first?.dateISO, original.dateISO)
        XCTAssertEqual(all.first?.seq, original.seq)
    }

    // MARK: - 4) تعديل عملية غير موجودة -> فشل صريح

    func test_edit_nonexistentTransaction_failsExplicitly() throws {
        let context = try makeContext()

        let result = try TransactionService.edit(id: "missing", newAmount: 1000, newNote: "", in: context)

        assertFailure(result, expected: .ledger(.transactionNotFound))
    }

    // MARK: - 5) حذف عملية موجودة -> لم تعد موجودة

    func test_delete_existingTransaction_removesIt() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(t1, in: context))

        assertSuccess(try TransactionService.delete(id: "t1", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - 6) حذف عملية غير موجودة -> فشل صريح (بنفس دلالة الخطأ الموجودة أصلًا)

    func test_delete_nonexistentTransaction_failsExplicitly() throws {
        let context = try makeContext()

        let result = try TransactionService.delete(id: "missing", in: context)

        assertFailure(result, expected: .ledger(.transactionNotFound))
    }

    // MARK: - 7) تسلسل CRUD كامل: إضافة -> إضافة -> تعديل -> حذف -> إعادة تحميل

    func test_crudSequence_addAddEditDelete_thenReloadFromNewContainer_reflectsFinalState() throws {
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .deposit, amount: 200_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)

        do {
            let context = try makeContext()
            assertSuccess(try TransactionService.add(t1, in: context))
            assertSuccess(try TransactionService.add(t2, in: context))
            assertSuccess(try TransactionService.edit(id: "t1", newAmount: 550_000, newNote: "معدَّل", in: context))
            assertSuccess(try TransactionService.delete(id: "t2", in: context))
        }
        // الـ container/context أعلاه خرجا عن النطاق تمامًا هنا قبل إعادة الفتح.

        let final = try TransactionStore.fetchAll(from: try makeContext())

        XCTAssertEqual(final.count, 1)
        XCTAssertEqual(final.first?.id, "t1")
        XCTAssertEqual(final.first?.amount, 550_000)
        XCTAssertEqual(final.first?.note, "معدَّل")
    }

    // MARK: - 8) حالة الدفتر بعد الإضافة

    func test_ledgerState_afterAdd_reflectsNewBalance() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)

        assertSuccess(try TransactionService.add(deposit, in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(LedgerCalculator.recompute(all).finalBalance, 500_000)
    }

    // MARK: - 9) حالة الدفتر بعد التعديل

    func test_ledgerState_afterEdit_reflectsUpdatedBalance() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        assertSuccess(try TransactionService.add(deposit, in: context))
        assertSuccess(try TransactionService.add(withdraw, in: context))

        assertSuccess(try TransactionService.edit(id: "t1", newAmount: 700_000, newNote: "", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(LedgerCalculator.recompute(all).finalBalance, 600_000)
    }

    // MARK: - 10) حالة الدفتر بعد الحذف

    func test_ledgerState_afterDelete_reflectsRemainingBalance() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        assertSuccess(try TransactionService.add(deposit, in: context))
        assertSuccess(try TransactionService.add(withdraw, in: context))

        assertSuccess(try TransactionService.delete(id: "t2", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(LedgerCalculator.recompute(all).finalBalance, 500_000)
    }

    // MARK: - 11) عملية مالية غير صالحة تُرفَض وفق قواعد Domain الموجودة أصلًا

    func test_add_withdrawalExceedingBalance_isRejectedByExistingDomainRule() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(deposit, in: context))

        let tooLargeWithdrawal = tx(id: "t2", type: .withdraw, amount: 200_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        let result = try TransactionService.add(tooLargeWithdrawal, in: context)

        assertFailure(result, expected: .ledger(.wouldProduceNegativeBalance))
        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - 12) لا يُنشئ التعديل سجلًا مكررًا أبدًا

    func test_edit_doesNotCreateDuplicateRecord() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(deposit, in: context))

        assertSuccess(try TransactionService.edit(id: "t1", newAmount: 600_000, newNote: "تعديل أول", in: context))
        assertSuccess(try TransactionService.edit(id: "t1", newAmount: 650_000, newNote: "تعديل ثانٍ", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.amount, 650_000)
    }

    // MARK: - 13) معرّفات العمليات تبقى صحيحة عبر العمليات

    func test_transactionIDs_remainStableAcrossOperations() throws {
        let context = try makeContext()
        let t1 = tx(id: "stable-id-1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(t1, in: context))
        assertSuccess(try TransactionService.edit(id: "stable-id-1", newAmount: 600_000, newNote: "x", in: context))

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.first?.id, "stable-id-1")
    }

    // MARK: - 14) دقة التاريخ تبقى بلا فقدان

    func test_datePrecision_isLosslessThroughAddAndReload() throws {
        let preciseDateString = "2026-08-21T14:23:45.789Z"
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: preciseDateString, seq: 1)

        do {
            let context = try makeContext()
            assertSuccess(try TransactionService.add(t1, in: context))
        }

        let all = try TransactionStore.fetchAll(from: try makeContext())
        XCTAssertEqual(all.first?.dateISO, t1.dateISO)
    }

    // MARK: - 15) seq يبقى Double محفوظًا تمامًا بلا تقريب

    func test_seq_remainsExactDoubleThroughAddAndReload() throws {
        let preciseSeq = 1_755_000_000_123.456789
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: preciseSeq)

        do {
            let context = try makeContext()
            assertSuccess(try TransactionService.add(t1, in: context))
        }

        let all = try TransactionStore.fetchAll(from: try makeContext())
        XCTAssertEqual(all.first?.seq, preciseSeq)
    }

    // MARK: - تغطية إضافية: كل حالة خطأ جديدة (invalidAmount/duplicateID) يجب اختبارها صراحةً

    func test_add_invalidAmount_isRejected() throws {
        let context = try makeContext()
        let zeroAmount = tx(id: "t1", type: .deposit, amount: 0, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)

        let result = try TransactionService.add(zeroAmount, in: context)

        assertFailure(result, expected: .invalidAmount)
        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertTrue(all.isEmpty)
    }

    func test_edit_invalidAmount_isRejected() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(deposit, in: context))

        let result = try TransactionService.edit(id: "t1", newAmount: 0, newNote: "", in: context)

        assertFailure(result, expected: .invalidAmount)
        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.first?.amount, 500_000)
    }

    func test_add_duplicateID_isRejected() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        assertSuccess(try TransactionService.add(t1, in: context))

        let duplicate = tx(id: "t1", type: .deposit, amount: 1_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        let result = try TransactionService.add(duplicate, in: context)

        assertFailure(result, expected: .duplicateID)
        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
    }
}
