import Foundation
import XCTest
import SwiftData
@testable import QasatiDashboardFeature
@testable import QasatiPersistence
@testable import QasatiDomain

final class DashboardViewModelTests: XCTestCase {

    // نفس نمط العزل المُستخدَم في Phases 2/3: ملف تخزين حقيقي فريد لكل اختبار.
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QasatiDashboardFeatureTests-\(UUID().uuidString)")
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
        dateISOString: String,
        seq: Double
    ) -> Transaction {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateISOString) else {
            fatalError("تاريخ اختبار غير صالح: \(dateISOString)")
        }
        return Transaction(id: id, type: type, amount: amount, note: "", dateISO: date, seq: seq)
    }

    @MainActor
    func test_load_emptyStore_producesZeroedSummary() throws {
        let context = try makeContext()
        let viewModel = DashboardViewModel(context: context)

        viewModel.load()

        XCTAssertEqual(viewModel.summary.balance, 0)
        XCTAssertEqual(viewModel.summary.totalDeposits, 0)
        XCTAssertEqual(viewModel.summary.totalWithdrawals, 0)
        XCTAssertEqual(viewModel.summary.countIn, 0)
        XCTAssertEqual(viewModel.summary.countOut, 0)
        XCTAssertEqual(viewModel.summary.monthNet, 0)
        XCTAssertNil(viewModel.loadError)
    }

    @MainActor
    func test_load_afterSavingTransactions_matchesIndependentLedgerCalculatorResult() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let viewModel = DashboardViewModel(context: context)
        viewModel.load()

        let expected = LedgerCalculator.summary(for: [t1, t2])
        XCTAssertEqual(viewModel.summary.balance, expected.balance)
        XCTAssertEqual(viewModel.summary.totalDeposits, expected.totalDeposits)
        XCTAssertEqual(viewModel.summary.totalWithdrawals, expected.totalWithdrawals)
        XCTAssertEqual(viewModel.summary.countIn, expected.countIn)
        XCTAssertEqual(viewModel.summary.countOut, expected.countOut)
        XCTAssertNil(viewModel.loadError)
    }

    @MainActor
    func test_load_reflectsDataFromNewContainerPointingAtSameStore() throws {
        let t1 = tx(id: "t1", type: .deposit, amount: 250_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)

        do {
            let writeContext = try makeContext()
            try TransactionStore.save(t1, in: writeContext)
        }
        // السياق أعلاه خرج عن النطاق تمامًا؛ القراءة التالية عبر container/context جديدين
        // تمامًا يشيران لنفس ملف التخزين — تحقق حقيقي، وليس اعتمادًا على ذاكرة الكائن.

        let readContext = try makeContext()
        let viewModel = DashboardViewModel(context: readContext)
        viewModel.load()

        XCTAssertEqual(viewModel.summary.balance, 250_000)
        XCTAssertEqual(viewModel.summary.countIn, 1)
    }
}
