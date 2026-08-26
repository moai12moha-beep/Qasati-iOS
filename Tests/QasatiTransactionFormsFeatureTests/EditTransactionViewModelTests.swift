import Foundation
import XCTest
import SwiftData
@testable import QasatiTransactionFormsFeature
@testable import QasatiPersistence
@testable import QasatiDomain

final class EditTransactionViewModelTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditTransactionViewModelTests-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    override func tearDownWithError() throws {
        if let storeURL, FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        storeURL = nil
        try super.tearDownWithError()
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([PersistedTransaction.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
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

    // تعديل صحيح -> يُحفظ بشكل صحيح، id/dateISO/seq لا تتغير
    @MainActor
    func test_save_validEdit_persistsAndPreservesIdentity() throws {
        let context = try makeContext()
        let original = tx(id: "t1", type: .deposit, amount: 500_000, note: "قديم", dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(original, in: context)

        let viewModel = EditTransactionViewModel(transaction: original, context: context)
        viewModel.amountText = "600,000"
        viewModel.noteText = "جديد"
        viewModel.save()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.didSaveSuccessfully)

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "t1")
        XCTAssertEqual(all.first?.amount, 600_000)
        XCTAssertEqual(all.first?.note, "جديد")
        XCTAssertEqual(all.first?.dateISO, original.dateISO)
        XCTAssertEqual(all.first?.seq, original.seq)
    }

    // تعديل ينتج رصيدًا سالبًا في أي نقطة تاريخية -> رفض بالرسالة الدقيقة، بلا حفظ
    @MainActor
    func test_save_editProducingNegativeBalance_isRejectedWithExactMessage() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "t2", type: .withdraw, amount: 400_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(deposit, in: context)
        try TransactionStore.save(withdraw, in: context)

        let viewModel = EditTransactionViewModel(transaction: deposit, context: context)
        viewModel.amountText = "300000" // 300,000 - 400,000 = رصيد سالب لحظي

        viewModel.save()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "لا يمكن حفظ التعديل: سيؤدي إلى رصيد سالب في السجل.")

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.first { $0.id == "t1" }?.amount, 500_000) // لم يتغيّر
    }

    // مبلغ غير صالح -> يُرفض قبل لمس التخزين إطلاقًا
    @MainActor
    func test_save_invalidAmount_isRejectedBeforeTouchingPersistence() throws {
        let context = try makeContext()
        let original = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(original, in: context)

        let viewModel = EditTransactionViewModel(transaction: original, context: context)
        viewModel.amountText = "0"
        viewModel.save()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "يرجى إدخال مبلغ صحيح.")
        XCTAssertEqual(try TransactionStore.fetchAll(from: context).first?.amount, 500_000)
    }

    // عملية غير موجودة (سيناريو دفاعي) -> رسالة "تعذّر العثور على العملية."
    @MainActor
    func test_save_nonexistentTransaction_failsWithNotFoundMessage() throws {
        let context = try makeContext()
        let ghost = tx(id: "ghost", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)

        let viewModel = EditTransactionViewModel(transaction: ghost, context: context)
        viewModel.amountText = "150000"
        viewModel.save()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "تعذّر العثور على العملية.")
    }

    // يحافظ على النوع والتاريخ الأصليين للعرض القرائي فقط، بلا أي طريق لتغييرهما
    @MainActor
    func test_init_exposesReadOnlyTypeAndOriginalDate() throws {
        let context = try makeContext()
        let original = tx(id: "t1", type: .withdraw, amount: 200_000, dateISOString: "2026-08-05T10:00:00.000Z", seq: 1)

        let viewModel = EditTransactionViewModel(transaction: original, context: context)

        XCTAssertEqual(viewModel.type, .withdraw)
        XCTAssertEqual(viewModel.originalDateISO, original.dateISO)
        XCTAssertEqual(viewModel.amountText, "200000")
        XCTAssertEqual(viewModel.noteText, "")
    }
}
