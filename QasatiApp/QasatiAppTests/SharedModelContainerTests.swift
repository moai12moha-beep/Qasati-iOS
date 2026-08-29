import XCTest
import SwiftData
@testable import QasatiApp
import QasatiPersistence
import QasatiDashboardFeature
import QasatiHistoryFeature
import QasatiTransactionFormsFeature
import QasatiDomain

/// يثبت أن ModelContext واحد مشترك (تمامًا كما يوفّره QasatiApp.init عبر
/// .modelContainer(container) الوحيد) مرئي فورًا لأكثر من ViewModel مستقلة تُبنى منه —
/// بلا أي حاوية إنتاجية ثانية، وبلا أي بيانات مالية مكرَّرة يدويًا.
final class SharedModelContainerTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedModelContainerTests-\(UUID().uuidString)")
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
    func test_oneSharedModelContext_visibleToDashboardAndHistoryViewModels() throws {
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
        XCTAssertEqual(history.allEntries.count, 1)
        XCTAssertEqual(history.allEntries.first?.transaction.amount, 500_000)
    }
}
