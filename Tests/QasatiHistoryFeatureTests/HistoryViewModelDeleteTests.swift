import Foundation
import XCTest
import SwiftData
@testable import QasatiHistoryFeature
@testable import QasatiPersistence
@testable import QasatiDomain

/// اختبارات delete(id:) المُضافة في Phase 8 على HistoryViewModel. ملف منفصل عمدًا عن
/// HistoryViewModelTests.swift المحمي (Phase 7) — لا تعديل عليه.
final class HistoryViewModelDeleteTests: XCTestCase {

    private var storeURL: URL!
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryViewModelDeleteTests-\(UUID().uuidString)")
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

    // حذف ناجح -> يُزال من allEntries عبر load() تلقائيًا، بلا خطأ
    @MainActor
    func test_delete_existingTransaction_removesItAndRefreshesFromPersistence() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .deposit, amount: 200_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        XCTAssertEqual(viewModel.allEntries.count, 2)

        viewModel.delete(id: "t1")

        XCTAssertNil(viewModel.deleteErrorMessage)
        XCTAssertTrue(viewModel.didDeleteSucceed)
        XCTAssertEqual(viewModel.allEntries.map(\.transaction.id), ["t2"])
        // تحقق مستقل من طبقة التخزين نفسها، وليس فقط من حالة الـ ViewModel
        let persisted = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(persisted.map(\.id), ["t2"])
    }

    // حذف يُنتج رصيدًا سالبًا (OQ-1) -> يُرفض بالرسالة الدقيقة، العملية تبقى موجودة
    @MainActor
    func test_delete_producingNegativeBalance_isRejectedAndEntryRemains() throws {
        let context = try makeContext()
        let deposit = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let withdraw = tx(id: "t2", type: .withdraw, amount: 400_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        try TransactionStore.save(deposit, in: context)
        try TransactionStore.save(withdraw, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        viewModel.delete(id: "t1")

        XCTAssertEqual(viewModel.deleteErrorMessage, "لا يمكن حذف هذه العملية: سيؤدي ذلك إلى رصيد سالب في السجل.")
        XCTAssertFalse(viewModel.didDeleteSucceed)
        XCTAssertEqual(viewModel.allEntries.count, 2) // لم يتغيّر شيء
        let persisted = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(Set(persisted.map(\.id)), Set(["t1", "t2"]))
    }

    // حذف آخر عملية متبقية -> isEmpty تصبح true
    @MainActor
    func test_delete_lastRemainingTransaction_setsIsEmptyTrue() throws {
        let context = try makeContext()
        let only = tx(id: "t1", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(only, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        XCTAssertFalse(viewModel.isEmpty)

        viewModel.delete(id: "t1")

        XCTAssertNil(viewModel.deleteErrorMessage)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertTrue(viewModel.filteredEntries.isEmpty)
    }

    // حذف عملية واحدة ضمن عدة عمليات، مع فلتر نشط -> filteredEntries تتحدّث بشكل صحيح
    @MainActor
    func test_delete_underActiveFilter_updatesFilteredEntriesCorrectly() throws {
        let context = try makeContext()
        let deposit1 = tx(id: "d1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let deposit2 = tx(id: "d2", type: .deposit, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)
        let withdraw = tx(id: "w1", type: .withdraw, amount: 50_000, dateISOString: "2026-08-03T08:00:00.000Z", seq: 3)
        try TransactionStore.save(deposit1, in: context)
        try TransactionStore.save(deposit2, in: context)
        try TransactionStore.save(withdraw, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.typeFilter = .deposit
        XCTAssertEqual(Set(viewModel.filteredEntries.map(\.transaction.id)), Set(["d1", "d2"]))

        viewModel.delete(id: "d1")

        XCTAssertNil(viewModel.deleteErrorMessage)
        XCTAssertEqual(viewModel.filteredEntries.map(\.transaction.id), ["d2"])
    }

    // حذف عملية غير موجودة (سيناريو دفاعي) -> رسالة واضحة، بلا انهيار
    @MainActor
    func test_delete_nonexistentTransaction_setsNotFoundMessage() throws {
        let context = try makeContext()
        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()

        viewModel.delete(id: "does-not-exist")

        XCTAssertEqual(viewModel.deleteErrorMessage, "تعذّر العثور على العملية.")
        XCTAssertFalse(viewModel.didDeleteSucceed)
    }

    // didDeleteSucceed: false قبل أي محاولة، true بعد نجاح حقيقي فقط، ويعود false في أول
    // محاولة فاشلة تالية — وليست قيمة "لاصقة" (Phase 16 refresh-signal fix)
    @MainActor
    func test_didDeleteSucceed_falseInitially_trueOnlyAfterSuccess_resetsOnNextFailedAttempt() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(t1, in: context)

        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        XCTAssertFalse(viewModel.didDeleteSucceed)

        viewModel.delete(id: "does-not-exist")
        XCTAssertFalse(viewModel.didDeleteSucceed)

        viewModel.delete(id: "t1")
        XCTAssertTrue(viewModel.didDeleteSucceed)

        viewModel.delete(id: "does-not-exist-again")
        XCTAssertFalse(viewModel.didDeleteSucceed)
    }

    // clearDeleteError يُصفّر الحالة كما تستدعيه الـ View عند إغلاق تنبيه الخطأ
    @MainActor
    func test_clearDeleteError_resetsMessage() throws {
        let context = try makeContext()
        let viewModel = HistoryViewModel(context: context, calendar: utcCalendar)
        viewModel.load()
        viewModel.delete(id: "missing")
        XCTAssertNotNil(viewModel.deleteErrorMessage)

        viewModel.clearDeleteError()

        XCTAssertNil(viewModel.deleteErrorMessage)
    }
}
