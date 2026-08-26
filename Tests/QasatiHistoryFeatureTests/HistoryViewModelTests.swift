import Foundation
import XCTest
import SwiftData
@testable import QasatiHistoryFeature
@testable import QasatiPersistence
@testable import QasatiDomain

final class HistoryViewModelTests: XCTestCase {

    // نفس نمط العزل المُستخدَم في كل الأهداف السابقة: ملف تخزين حقيقي فريد لكل اختبار.
    private var storeURL: URL!

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryViewModelTests-\(UUID().uuidString)")
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

    // 1) سجل فارغ
    @MainActor
    func test_emptyLedger_isEmptyTrue_noEntries() throws {
        let context = try makeContext()
        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)

        viewModel.load()

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertFalse(viewModel.hasNoResults)
        XCTAssertTrue(viewModel.filteredEntries.isEmpty)
    }

    // 2) كل العمليات
    @MainActor
    func test_allTransactions_areLoaded() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertEqual(viewModel.filteredEntries.count, 2)
    }

    // 3) الأحدث أولًا
    @MainActor
    func test_filteredEntries_showsNewestFirst() throws {
        let context = try makeContext()
        let older = tx(id: "older", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let newer = tx(id: "newer", type: .deposit, amount: 200_000, dateISOString: "2026-08-05T08:00:00.000Z", seq: 2)
        try TransactionStore.save(older, in: context)
        try TransactionStore.save(newer, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["newer", "older"])
    }

    // 4) فلتر الإيداعات
    @MainActor
    func test_depositFilter_showsOnlyDeposits() throws {
        let context = try makeContext()
        let deposit = tx(id: "d1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "w1", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(deposit, in: context)
        try TransactionStore.save(withdraw, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.typeFilter = .deposit

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["d1"])
    }

    // 5) فلتر السحوبات
    @MainActor
    func test_withdrawFilter_showsOnlyWithdrawals() throws {
        let context = try makeContext()
        let deposit = tx(id: "d1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "w1", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(deposit, in: context)
        try TransactionStore.save(withdraw, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.typeFilter = .withdraw

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["w1"])
    }

    // 6) فلتر الشهر
    @MainActor
    func test_monthFilter_showsOnlyMatchingMonth() throws {
        let context = try makeContext()
        let august = tx(id: "aug", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let july = tx(id: "jul", type: .deposit, amount: 300_000, dateISOString: "2026-07-01T08:00:00.000Z", seq: 2)
        try TransactionStore.save(august, in: context)
        try TransactionStore.save(july, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.selectedMonthKey = "2026-08"

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["aug"])
    }

    // 7) البحث في الملاحظات
    @MainActor
    func test_noteSearch_isCaseInsensitiveSubstringMatch() throws {
        let context = try makeContext()
        let salary = tx(id: "t1", type: .deposit, amount: 500_000, note: "راتب شهر آب", dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let groceries = tx(id: "t2", type: .withdraw, amount: 50_000, note: "مصاريف شخصية", dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(salary, in: context)
        try TransactionStore.save(groceries, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.searchText = "راتب"

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["t1"])
    }

    // 8) فلاتر مركّبة + بحث معًا (AND)
    @MainActor
    func test_combinedTypeMonthAndSearch_appliesAllAsAND() throws {
        let context = try makeContext()
        let matches = tx(id: "match", type: .deposit, amount: 500_000, note: "راتب شهر آب", dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let wrongType = tx(id: "wrongType", type: .withdraw, amount: 100_000, note: "راتب", dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        let wrongMonth = tx(id: "wrongMonth", type: .deposit, amount: 100_000, note: "راتب", dateISOString: "2026-07-02T08:00:00.000Z", seq: 3)
        let wrongSearch = tx(id: "wrongSearch", type: .deposit, amount: 100_000, note: "غير ذلك", dateISOString: "2026-08-03T08:00:00.000Z", seq: 4)
        for t in [matches, wrongType, wrongMonth, wrongSearch] {
            try TransactionStore.save(t, in: context)
        }

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.typeFilter = .deposit
        viewModel.selectedMonthKey = "2026-08"
        viewModel.searchText = "راتب"

        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["match"])
    }

    // 9) حالة لا نتائج
    @MainActor
    func test_noResultsState_whenTransactionsExistButFilterMatchesNone() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, note: "راتب", dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(t1, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.searchText = "نص غير موجود إطلاقًا"

        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertTrue(viewModel.hasNoResults)
        XCTAssertTrue(viewModel.filteredEntries.isEmpty)
    }

    // 10) balanceAfter مأخوذ من LedgerCalculator مباشرة، بلا إعادة حساب محلي
    @MainActor
    func test_balanceAfter_matchesIndependentLedgerCalculatorResult() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        let expected = LedgerCalculator.recompute([t1, t2])
        for entry in viewModel.filteredEntries {
            let expectedEntry = expected.ordered.first { $0.transaction.id == entry.transaction.id }
            XCTAssertEqual(entry.balanceAfter, expectedEntry?.balanceAfter)
        }
    }

    // 11) الترتيب حسب dateISO ثم seq (موروث من LedgerCalculator)
    @MainActor
    func test_ordering_tieBreaksBySeq_whenDateISOIsIdentical() throws {
        let context = try makeContext()
        let sameDate = "2026-08-10T12:00:00.000Z"
        let a = tx(id: "a", type: .deposit, amount: 100, dateISOString: sameDate, seq: 3)
        let b = tx(id: "b", type: .deposit, amount: 200, dateISOString: sameDate, seq: 1)
        let c = tx(id: "c", type: .deposit, amount: 300, dateISOString: sameDate, seq: 2)
        try TransactionStore.save(a, in: context)
        try TransactionStore.save(b, in: context)
        try TransactionStore.save(c, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        // تصاعديًا حسب seq: b, c, a — وبعد العكس للأحدث أولًا: a, c, b
        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["a", "c", "b"])
    }

    // إضافي: availableMonthKeys يعكس فقط الأشهر الموجودة فعليًا في البيانات، الأحدث أولًا
    @MainActor
    func test_availableMonthKeys_reflectsActualDataOnly_newestFirst() throws {
        let context = try makeContext()
        let august = tx(id: "aug", type: .deposit, amount: 100, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let june = tx(id: "jun", type: .deposit, amount: 100, dateISOString: "2026-06-01T08:00:00.000Z", seq: 2)
        try TransactionStore.save(august, in: context)
        try TransactionStore.save(june, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        XCTAssertEqual(viewModel.availableMonthKeys, ["2026-08", "2026-06"])
    }
}
