import Foundation
import XCTest
import SwiftData
@testable import QasatiDashboardFeature
@testable import QasatiTransactionFormsFeature
@testable import QasatiPersistence
@testable import QasatiDomain

/// اختبار تكامل حقيقي عبر الطبقات: TransactionFormViewModel.submit() (نموذج الإيداع/السحب
/// الفعلي) → TransactionService → SwiftData → DashboardViewModel.load()، على نفس ملف
/// التخزين الحقيقي على القرص، بلا أي إدراج مباشر عبر TransactionStore.save كما تفعل بقية
/// اختبارات QasatiDashboardFeatureTests. الهدف: إثبات أن ما يُدخله المستخدم فعليًا عبر
/// شاشة الإيداع/السحب ينعكس بشكل صحيح على اللوحة الرئيسية، وليس فقط أن كل نصف من هذين
/// الهدفين صحيح بمعزل عن الآخر (Phase 13، القرار A).
final class DashboardIntegrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DashboardIntegrationTests-\(UUID().uuidString)")
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
    func test_depositSubmittedViaForm_isVisibleToDashboard_balanceMatchesLedgerCalculator() throws {
        let context = try makeContext()

        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500,000"
        form.noteText = "راتب شهر آب"
        form.submit()

        XCTAssertTrue(form.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        dashboard.load()

        let persisted = try TransactionStore.fetchAll(from: context)
        let expected = LedgerCalculator.summary(for: persisted)

        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(dashboard.summary.balance, expected.balance)
        XCTAssertEqual(dashboard.summary.balance, 500_000)
        XCTAssertEqual(dashboard.summary.totalDeposits, expected.totalDeposits)
        XCTAssertEqual(dashboard.summary.countIn, expected.countIn)
        XCTAssertNil(dashboard.loadError)
    }

    @MainActor
    func test_depositThenWithdrawalSubmittedViaForm_dashboardReflectsFinalBalance() throws {
        let context = try makeContext()

        let deposit = TransactionFormViewModel(type: .deposit, context: context)
        deposit.amountText = "500000"
        deposit.submit()
        XCTAssertTrue(deposit.didSaveSuccessfully)

        let withdrawal = TransactionFormViewModel(type: .withdraw, context: context)
        withdrawal.amountText = "200000"
        withdrawal.submit()
        XCTAssertTrue(withdrawal.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        dashboard.load()

        let persisted = try TransactionStore.fetchAll(from: context)
        let expected = LedgerCalculator.summary(for: persisted)

        XCTAssertEqual(dashboard.summary.balance, expected.balance)
        XCTAssertEqual(dashboard.summary.balance, 300_000)
        XCTAssertEqual(dashboard.summary.totalDeposits, expected.totalDeposits)
        XCTAssertEqual(dashboard.summary.totalWithdrawals, expected.totalWithdrawals)
        XCTAssertEqual(dashboard.summary.countIn, 1)
        XCTAssertEqual(dashboard.summary.countOut, 1)
    }

    @MainActor
    func test_withdrawalRejectedByForm_dashboardBalanceUnaffected() throws {
        let context = try makeContext()

        let deposit = TransactionFormViewModel(type: .deposit, context: context)
        deposit.amountText = "100000"
        deposit.submit()
        XCTAssertTrue(deposit.didSaveSuccessfully)

        let rejectedWithdrawal = TransactionFormViewModel(type: .withdraw, context: context)
        rejectedWithdrawal.amountText = "999999"
        rejectedWithdrawal.submit()
        XCTAssertFalse(rejectedWithdrawal.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        dashboard.load()

        XCTAssertEqual(dashboard.summary.balance, 100_000)
        XCTAssertEqual(dashboard.summary.countOut, 0)
    }
}
