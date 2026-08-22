import Foundation
import XCTest
import SwiftData
@testable import QasatiTransactionFormsFeature
@testable import QasatiPersistence
@testable import QasatiDomain

final class TransactionFormViewModelTests: XCTestCase {

    // نفس نمط العزل المُستخدَم في Phases 2-4: ملف تخزين حقيقي فريد لكل اختبار.
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QasatiTransactionFormsFeatureTests-\(UUID().uuidString)")
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

    @MainActor
    func test_submit_validDeposit_withNote_savesAndClearsForm() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)
        viewModel.amountText = "500,000"
        viewModel.noteText = "راتب شهر آب"

        viewModel.submit()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.amountText, "")
        XCTAssertEqual(viewModel.noteText, "")

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.type, .deposit)
        XCTAssertEqual(all.first?.amount, 500_000)
        XCTAssertEqual(all.first?.note, "راتب شهر آب")
        XCTAssertTrue(all.first?.id.hasPrefix("tx_") ?? false)
    }

    @MainActor
    func test_submit_validDeposit_withoutNote_savesEmptyNote() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)
        viewModel.amountText = "100000"

        viewModel.submit()

        XCTAssertTrue(viewModel.didSaveSuccessfully)
        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.first?.note, "")
    }

    @MainActor
    func test_submit_validWithdrawal_withinBalance_reducesBalance() throws {
        let context = try makeContext()
        let deposit = Transaction.creatingNew(type: .deposit, amount: 500_000, note: "")
        try TransactionStore.save(deposit, in: context)

        let viewModel = TransactionFormViewModel(type: .withdraw, context: context)
        viewModel.amountText = "200,000"

        viewModel.submit()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.didSaveSuccessfully)

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(LedgerCalculator.recompute(all).finalBalance, 300_000)
    }

    @MainActor
    func test_submit_withdrawalExceedingBalance_isRejectedWithCorrectMessage() throws {
        let context = try makeContext()
        let deposit = Transaction.creatingNew(type: .deposit, amount: 100_000, note: "")
        try TransactionStore.save(deposit, in: context)

        let viewModel = TransactionFormViewModel(type: .withdraw, context: context)
        viewModel.amountText = "200000"

        viewModel.submit()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "الرصيد غير كافٍ لإتمام عملية السحب.")
        XCTAssertEqual(viewModel.amountText, "200000") // لا يُفرَّغ النموذج عند الفشل

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1) // لم تُضَف عملية السحب المرفوضة
    }

    @MainActor
    func test_submit_invalidAmountText_isRejectedBeforeTouchingPersistence() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)
        viewModel.amountText = "abc"

        viewModel.submit()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "يرجى إدخال مبلغ صحيح.")

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertTrue(all.isEmpty)
    }

    @MainActor
    func test_submit_zeroAmount_isRejected() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)
        viewModel.amountText = "0"

        viewModel.submit()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "يرجى إدخال مبلغ صحيح.")
    }
}
