import XCTest
import SwiftData
@testable import QasatiApp
import QasatiPersistence
import QasatiDashboardFeature
import QasatiHistoryFeature
import QasatiTransactionFormsFeature
import QasatiSettingsFeature
import QasatiDomain

/// يختبر السلسلة الفعلية التي تستخدمها طبقة التطبيق للتحديث بعد التعديل: نجاح حقيقي عبر
/// الإشارة المباشرة (didSaveSuccessfully / didDeleteSucceed / didMutateSucceed — بالضبط
/// كما تراقبها AddTransactionTabView/HistoryTabView/SettingsTabView) → RefreshSignal.bump()
/// → إعادة تحميل الشاشات الأخرى (بالضبط كما يفعل .onChange(of: refreshSignal.version)) —
/// فتعكس الحقيقة المخزَّنة الفعلية، بلا أي ترقيع يدوي للرصيد. كل سيناريو يستخدم
/// ModelContainer معزولًا خاصًا به على القرص، بنفس نمط اختبارات SwiftPM القائمة.
final class AppRefreshIntegrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppRefreshIntegrationTests-\(UUID().uuidString)")
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

    // MARK: - Add deposit -> Dashboard

    @MainActor
    func test_addDeposit_signalsSuccess_refreshedDashboardReflectsPersistedTruth() throws {
        let context = try makeContext()
        let dashboard = DashboardViewModel(context: context)
        dashboard.load()
        XCTAssertEqual(dashboard.summary.balance, 0)

        let refreshSignal = RefreshSignal()
        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500000"
        form.submit()

        XCTAssertTrue(form.didSaveSuccessfully) // AddTransactionTabView's exact trigger
        refreshSignal.bump()
        dashboard.load() // AddTransactionTabView -> refreshSignal -> DashboardTabView reload

        XCTAssertEqual(dashboard.summary.balance, 500_000)
    }

    // MARK: - Add deposit -> History

    @MainActor
    func test_addDeposit_signalsSuccess_refreshedHistoryReflectsPersistedTruth() throws {
        let context = try makeContext()
        let history = HistoryViewModel(context: context)
        history.load()
        XCTAssertTrue(history.isEmpty)

        let refreshSignal = RefreshSignal()
        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500000"
        form.noteText = "راتب"
        form.submit()

        XCTAssertTrue(form.didSaveSuccessfully)
        refreshSignal.bump()
        history.load()

        XCTAssertEqual(history.allEntries.count, 1)
        XCTAssertEqual(history.allEntries.first?.transaction.note, "راتب")
    }

    // MARK: - Edit -> Dashboard and History

    @MainActor
    func test_editTransaction_signalsSuccess_refreshedDashboardAndHistoryReflectPersistedTruth() throws {
        let context = try makeContext()
        let original = TransactionFormViewModel(type: .deposit, context: context)
        original.amountText = "500000"
        original.submit()
        XCTAssertTrue(original.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        let history = HistoryViewModel(context: context)
        dashboard.load()
        history.load()
        guard let entry = history.allEntries.first else {
            return XCTFail("Expected one persisted entry to edit")
        }

        let refreshSignal = RefreshSignal()
        let editViewModel = EditTransactionViewModel(transaction: entry.transaction, context: context)
        editViewModel.amountText = "750000"
        editViewModel.save()

        XCTAssertTrue(editViewModel.didSaveSuccessfully) // HistoryView's internal onSaved trigger
        refreshSignal.bump()
        dashboard.load()
        history.load()

        XCTAssertEqual(dashboard.summary.balance, 750_000)
        XCTAssertEqual(history.allEntries.first?.transaction.amount, 750_000)
    }

    // MARK: - Delete -> Dashboard and History

    @MainActor
    func test_deleteTransaction_signalsSuccess_refreshedDashboardAndHistoryReflectPersistedTruth() throws {
        let context = try makeContext()
        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500000"
        form.submit()
        XCTAssertTrue(form.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        let history = HistoryViewModel(context: context)
        dashboard.load()
        history.load()
        guard let entry = history.allEntries.first else {
            return XCTFail("Expected one persisted entry to delete")
        }

        let refreshSignal = RefreshSignal()
        history.delete(id: entry.transaction.id)

        XCTAssertTrue(history.didDeleteSucceed) // HistoryView.onMutationSucceeded trigger
        refreshSignal.bump()
        dashboard.load()
        history.load()

        XCTAssertEqual(dashboard.summary.balance, 0)
        XCTAssertTrue(history.allEntries.isEmpty)
    }

    // MARK: - Import -> Dashboard and History

    @MainActor
    func test_importBackup_signalsSuccess_refreshedDashboardAndHistoryReflectPersistedTruth() throws {
        let context = try makeContext()
        let existing = TransactionFormViewModel(type: .deposit, context: context)
        existing.amountText = "100000"
        existing.submit()
        XCTAssertTrue(existing.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        let history = HistoryViewModel(context: context)
        dashboard.load()
        history.load()
        XCTAssertEqual(dashboard.summary.balance, 100_000)

        let refreshSignal = RefreshSignal()
        let settings = SettingsViewModel(context: context)
        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_imported","type":"deposit","amount":900000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!
        settings.importData(json)

        XCTAssertTrue(settings.didMutateSucceed) // SettingsTabView's exact trigger
        refreshSignal.bump()
        dashboard.load()
        history.load()

        XCTAssertEqual(dashboard.summary.balance, 900_000)
        XCTAssertEqual(history.allEntries.map(\.transaction.id), ["tx_imported"])
    }

    // MARK: - Wipe -> Dashboard and History

    @MainActor
    func test_wipe_signalsSuccess_refreshedDashboardAndHistoryShowEmptyState() throws {
        let context = try makeContext()
        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500000"
        form.submit()
        XCTAssertTrue(form.didSaveSuccessfully)

        let dashboard = DashboardViewModel(context: context)
        let history = HistoryViewModel(context: context)
        dashboard.load()
        history.load()
        XCTAssertEqual(dashboard.summary.balance, 500_000)
        XCTAssertFalse(history.isEmpty)

        let refreshSignal = RefreshSignal()
        let settings = SettingsViewModel(context: context)
        settings.wipeAllData()

        XCTAssertTrue(settings.didMutateSucceed)
        refreshSignal.bump()
        dashboard.load()
        history.load()

        XCTAssertEqual(dashboard.summary.balance, 0)
        XCTAssertTrue(history.isEmpty)
    }
}
