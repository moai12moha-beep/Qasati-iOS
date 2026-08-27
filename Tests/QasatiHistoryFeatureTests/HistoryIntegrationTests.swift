import Foundation
import XCTest
import SwiftData
@testable import QasatiHistoryFeature
@testable import QasatiTransactionFormsFeature
@testable import QasatiPersistence
@testable import QasatiDomain

/// اختبار تكامل حقيقي عبر الطبقات: TransactionFormViewModel.submit() → TransactionService
/// → SwiftData → HistoryViewModel.load()، على نفس ملف التخزين الحقيقي على القرص، بلا أي
/// إدراج مباشر عبر TransactionStore.save كما تفعل بقية اختبارات QasatiHistoryFeatureTests.
/// الهدف: إثبات أن ما يُدخله المستخدم فعليًا عبر شاشة الإيداع/السحب يظهر بالترتيب الصحيح
/// وبـ balanceAfter الصحيح في السجل، وليس فقط أن كل نصف من هذين الهدفين صحيح بمعزل عن
/// الآخر (Phase 13، القرار A).
final class HistoryIntegrationTests: XCTestCase {

    private var storeURL: URL!

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryIntegrationTests-\(UUID().uuidString)")
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
    func test_depositSubmittedViaForm_appearsInHistory() throws {
        let context = try makeContext()

        let form = TransactionFormViewModel(type: .deposit, context: context)
        form.amountText = "500,000"
        form.noteText = "راتب شهر آب"
        form.submit()
        XCTAssertTrue(form.didSaveSuccessfully)

        let history = HistoryViewModel(context: context, calendar: utcCalendar)
        history.load()

        XCTAssertFalse(history.isEmpty)
        XCTAssertEqual(history.filteredEntries.count, 1)
        XCTAssertEqual(history.filteredEntries.first?.transaction.note, "راتب شهر آب")
        XCTAssertEqual(history.filteredEntries.first?.transaction.amount, 500_000)
    }

    @MainActor
    func test_multipleTransactionsSubmittedViaForm_appearNewestFirst_withCorrectBalanceAfter() throws {
        let context = try makeContext()

        let deposit = TransactionFormViewModel(type: .deposit, context: context)
        deposit.amountText = "500000"
        deposit.submit()
        XCTAssertTrue(deposit.didSaveSuccessfully)

        let withdrawal = TransactionFormViewModel(type: .withdraw, context: context)
        withdrawal.amountText = "200000"
        withdrawal.submit()
        XCTAssertTrue(withdrawal.didSaveSuccessfully)

        let history = HistoryViewModel(context: context, calendar: utcCalendar)
        history.load()

        XCTAssertEqual(history.filteredEntries.count, 2)

        // الأحدث أولًا: السحب (أُرسل ثانيًا) يجب أن يظهر أولًا.
        XCTAssertEqual(history.filteredEntries.first?.transaction.type, .withdraw)
        XCTAssertEqual(history.filteredEntries.last?.transaction.type, .deposit)

        let persisted = try TransactionStore.fetchAll(from: context)
        let expected = LedgerCalculator.recompute(persisted)
        for entry in history.filteredEntries {
            let expectedEntry = expected.ordered.first { $0.transaction.id == entry.transaction.id }
            XCTAssertEqual(entry.balanceAfter, expectedEntry?.balanceAfter)
        }

        // الرصيد بعد السحب (الأحدث) يجب أن يساوي الرصيد النهائي للسجل بأكمله.
        XCTAssertEqual(history.filteredEntries.first?.balanceAfter, 300_000)
    }

    @MainActor
    func test_withdrawalRejectedByForm_doesNotAppearInHistory() throws {
        let context = try makeContext()

        let deposit = TransactionFormViewModel(type: .deposit, context: context)
        deposit.amountText = "100000"
        deposit.submit()
        XCTAssertTrue(deposit.didSaveSuccessfully)

        let rejectedWithdrawal = TransactionFormViewModel(type: .withdraw, context: context)
        rejectedWithdrawal.amountText = "999999"
        rejectedWithdrawal.submit()
        XCTAssertFalse(rejectedWithdrawal.didSaveSuccessfully)

        let history = HistoryViewModel(context: context, calendar: utcCalendar)
        history.load()

        XCTAssertEqual(history.filteredEntries.count, 1)
        XCTAssertEqual(history.filteredEntries.first?.transaction.type, .deposit)
    }
}
