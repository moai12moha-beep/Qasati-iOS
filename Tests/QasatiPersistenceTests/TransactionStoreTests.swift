import Foundation
import XCTest
import SwiftData
@testable import QasatiPersistence
@testable import QasatiDomain

final class TransactionStoreTests: XCTestCase {

    // مسار ملف تخزين فريد لكل اختبار (وليس in-memory) — عمدًا: تخزين في الذاكرة فقط
    // لا يصلح لاختبار "إعادة تشغيل التطبيق" لأنه لا يوجد ملف مشترك بين ModelContainer
    // الكتابة وModelContainer القراءة، فسيبدو الاختبار ناجحًا حتى لو كان الحفظ الفعلي معطوبًا.
    // التخزين على ملف حقيقي على القرص هو الطريقة الصحيحة الوحيدة لمحاكاة ذلك فعليًا.
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QasatiPersistenceTests-\(UUID().uuidString)")
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

    private func sampleTransaction(
        id: String = "tx_test_1",
        type: TransactionType = .deposit,
        amount: Int = 500_000,
        note: String = "راتب شهر آب",
        dateISOString: String = "2026-08-01T08:30:00.123Z",
        seq: Double = 1_755_000_000_123.456
    ) -> Transaction {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateISOString) else {
            fatalError("تاريخ اختبار غير صالح: \(dateISOString)")
        }
        return Transaction(id: id, type: type, amount: amount, note: note, dateISO: date, seq: seq)
    }

    // 1+2+3) حفظ عملية، ثم إعادة تحميلها من ModelContainer/ModelContext جديدين تمامًا
    // يُشيران إلى نفس ملف التخزين — محاكاة حقيقية لإعادة تشغيل التطبيق.
    func test_save_thenReloadFromNewContainerPointingAtSameStore_preservesTransaction() throws {
        let original = sampleTransaction()

        do {
            let writeContainer = try makeContainer()
            let writeContext = ModelContext(writeContainer)
            try TransactionStore.save(original, in: writeContext)
        }
        // writeContainer/writeContext خرجا عن النطاق هنا تمامًا قبل إعادة الفتح، لضمان أن أي
        // بيانات تُسترجَع لاحقًا قادمة فعلًا من الملف على القرص، وليس من ذاكرة الكائن نفسه.

        let readContainer = try makeContainer()
        let readContext = ModelContext(readContainer)
        let reloaded = try TransactionStore.fetchAll(from: readContext)

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first, original)
    }

    // 4) مطابقة Transaction <-> PersistedTransaction بلا فقدان، حقلًا حقلًا
    //
    // ملاحظة مهمة: PersistedTransaction هو @Model من SwiftData، وليس نوعًا عاديًا —
    // الوصول إلى خصائصه يتطلب أن يكون مرتبطًا فعليًا بـ ModelContainer/ModelContext نشط،
    // وإلا يحدث Fatal error داخل SwiftData نفسها ("failed to find a currently active
    // container"). لذلك يُنشأ container/context حقيقيان هنا ويُدرَج الكائن فيهما فورًا
    // قبل قراءة أي خاصية منه — بدل الاعتماد ضمنيًا/بالصدفة على container من اختبار آخر.
    func test_mapping_transactionToPersistedAndBack_isLossless() throws {
        let original = sampleTransaction(
            id: "tx_roundtrip",
            type: .withdraw,
            amount: 42_000,
            note: "اختبار الجولة الكاملة",
            dateISOString: "2026-08-21T14:23:45.789Z",
            seq: 1_755_000_000_123.456789
        )

        let container = try makeContainer()
        let context = ModelContext(container)

        let persisted = TransactionStore.makePersisted(from: original)
        context.insert(persisted)

        XCTAssertEqual(persisted.id, original.id)
        XCTAssertEqual(persisted.type, "withdraw")
        XCTAssertEqual(persisted.amount, original.amount)
        XCTAssertEqual(persisted.note, original.note)
        XCTAssertEqual(persisted.dateISO, original.dateISO)
        XCTAssertEqual(persisted.seq, original.seq)

        let mappedBack = TransactionStore.makeTransaction(from: persisted)
        XCTAssertEqual(mappedBack, original)
    }

    // بيانات type تالفة يجب أن تُرفَض بوضوح (nil)، لا أن تتحول بصمت إلى قيمة افتراضية
    //
    // نفس الملاحظة أعلاه: يجب container/context حقيقيان قبل أي وصول لخاصية على الكائن.
    func test_mapping_unknownTypeRawValue_returnsNilRatherThanSilentlyDefaulting() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let corrupted = PersistedTransaction(
            id: "tx_bad",
            type: "not_a_real_type",
            amount: 1000,
            note: "",
            dateISO: Date(),
            seq: 1
        )
        context.insert(corrupted)

        XCTAssertNil(TransactionStore.makeTransaction(from: corrupted))
    }

    // 5) عمليات تخزين إضافية ضمن نطاق Phase 2 المعتمد: حفظ عدة عمليات واسترجاعها كاملة
    func test_save_multipleTransactions_allAreRetrievable() throws {
        let t1 = sampleTransaction(id: "tx_1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        let t2 = sampleTransaction(id: "tx_2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T08:00:00.000Z", seq: 2)

        let container = try makeContainer()
        let context = ModelContext(container)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let all = try TransactionStore.fetchAll(from: context)

        XCTAssertEqual(Set(all.map(\.id)), Set([t1.id, t2.id]))
        XCTAssertEqual(all.first { $0.id == t1.id }, t1)
        XCTAssertEqual(all.first { $0.id == t2.id }, t2)
    }

    func test_fetchAll_emptyStore_returnsEmptyArray() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertTrue(all.isEmpty)
    }
}
