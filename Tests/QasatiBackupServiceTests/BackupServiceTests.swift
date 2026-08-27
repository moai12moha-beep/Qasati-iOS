import Foundation
import XCTest
import SwiftData
@testable import QasatiBackupService
@testable import QasatiPersistence
@testable import QasatiDomain

final class BackupServiceTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceTests-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    override func tearDownWithError() throws {
        if let storeURL, FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        storeURL = nil
        try super.tearDownWithError()
    }

    private func makeContext(url: URL? = nil) throws -> ModelContext {
        let schema = Schema([PersistedTransaction.self])
        let configuration = ModelConfiguration(schema: schema, url: url ?? storeURL)
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

    private func assertUnchanged(_ context: ModelContext, expected: [Transaction], file: StaticString = #filePath, line: UInt = #line) throws {
        let current = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(Set(current.map(\.id)), Set(expected.map(\.id)), "لم يعد يطابق المجموعة الأصلية بعد رفض الاستيراد", file: file, line: line)
        XCTAssertEqual(current.count, expected.count, file: file, line: line)
    }

    // MARK: - Export

    @MainActor
    func test_export_emptyStore_producesPayloadWithCorrectAppAndVersionAndEmptyTransactions() throws {
        let context = try makeContext()

        let data = try BackupService.export(from: context)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["app"] as? String, "qasati")
        XCTAssertEqual(json?["version"] as? Int, 1)
        XCTAssertNotNil(json?["exportedAt"])
        XCTAssertEqual((json?["transactions"] as? [Any])?.count, 0)
    }

    // MARK: - Round trip (lossless: dateISO/seq preserved exactly)

    @MainActor
    func test_exportThenImport_intoSameContext_roundTripsLosslessly() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, note: "راتب شهر آب", dateISOString: "2026-08-01T08:30:00.123Z", seq: 1_755_000_000_123.456789)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T10:15:30.500Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let data = try BackupService.export(from: context)
        let result = BackupService.importBackup(data, into: context)

        guard case .success(let count) = result else {
            return XCTFail("توقعت نجاح الاستيراد، النتيجة: \(result)")
        }
        XCTAssertEqual(count, 2)

        let restored = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(Set(restored.map(\.id)), Set(["t1", "t2"]))

        let r1 = restored.first { $0.id == "t1" }
        XCTAssertEqual(r1?.type, .deposit)
        XCTAssertEqual(r1?.amount, 500_000)
        XCTAssertEqual(r1?.note, "راتب شهر آب")
        XCTAssertEqual(r1?.dateISO, t1.dateISO)
        XCTAssertEqual(r1?.seq, t1.seq)

        let r2 = restored.first { $0.id == "t2" }
        XCTAssertEqual(r2?.dateISO, t2.dateISO)
        XCTAssertEqual(r2?.seq, t2.seq)
    }

    @MainActor
    func test_exportThenImport_intoDifferentStore_roundTripsLosslessly() throws {
        // ملف تخزين ثانٍ منفصل تمامًا عن storeURL الخاص بهذا الاختبار — يحاكي استعادة
        // نسخة احتياطية على جهاز/تثبيت مختلف تمامًا، وليس مجرد نفس السياق.
        let otherStoreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceTests-other-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: otherStoreURL) }

        let sourceContext = try makeContext()
        let original = tx(id: "t1", type: .deposit, amount: 250_000, note: "ملاحظة", dateISOString: "2026-08-05T12:00:00.000Z", seq: 42.5)
        try TransactionStore.save(original, in: sourceContext)
        let data = try BackupService.export(from: sourceContext)

        let destinationContext = try makeContext(url: otherStoreURL)
        let result = BackupService.importBackup(data, into: destinationContext)

        guard case .success = result else {
            return XCTFail("توقعت نجاح الاستيراد، النتيجة: \(result)")
        }
        let restored = try TransactionStore.fetchAll(from: destinationContext)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, "t1")
        XCTAssertEqual(restored.first?.dateISO, original.dateISO)
        XCTAssertEqual(restored.first?.seq, original.seq)
    }

    // MARK: - Strict schema: bare array rejected

    @MainActor
    func test_import_bareTransactionArray_isRejectedAsMalformed() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let bareArray = """
        [{"id":"tx_1","type":"deposit","amount":1000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}]
        """.data(using: .utf8)!

        let result = BackupService.importBackup(bareArray, into: context)

        XCTAssertEqual(result, .failure(.malformedJSON))
        try assertUnchanged(context, expected: [existing])
    }

    // MARK: - app / version validation

    @MainActor
    func test_import_wrongApp_isRejected() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let json = """
        {"app":"not-qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_1","type":"deposit","amount":1000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.unsupportedApp))
        try assertUnchanged(context, expected: [existing])
    }

    @MainActor
    func test_import_unsupportedVersion_isRejected() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let json = """
        {"app":"qasati","version":2,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_1","type":"deposit","amount":1000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.unsupportedVersion))
        try assertUnchanged(context, expected: [existing])
    }

    // MARK: - Empty transactions rejected

    @MainActor
    func test_import_emptyTransactionsArray_isRejected() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.emptyTransactions))
        try assertUnchanged(context, expected: [existing])
    }

    // MARK: - Invalid record rejects whole import (all-or-nothing)

    @MainActor
    func test_import_oneInvalidAmountAmongValidRecords_rejectsWholeImport() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_valid","type":"deposit","amount":500000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1},
          {"id":"tx_invalid","type":"withdraw","amount":0,"note":"","dateISO":"2026-08-02T00:00:00.000Z","seq":2}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.invalidTransactionRecord))
        try assertUnchanged(context, expected: [existing]) // لا "tx_valid" ولا "tx_invalid" — لا استيراد جزئي
    }

    @MainActor
    func test_import_negativeAmountRecord_rejectsWholeImport() throws {
        let context = try makeContext()
        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_1","type":"deposit","amount":-500,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.invalidTransactionRecord))
        XCTAssertTrue(try TransactionStore.fetchAll(from: context).isEmpty)
    }

    // MARK: - Invalid import preserves pre-existing data exactly (Phase 13, decision C)

    @MainActor
    func test_import_invalidBackup_doesNotAlterExistingData() throws {
        let context = try makeContext()
        let existing1 = tx(id: "keep1", type: .deposit, amount: 500_000, note: "راتب", dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        let existing2 = tx(id: "keep2", type: .withdraw, amount: 100_000, note: "مصاريف", dateISOString: "2026-08-02T00:00:00.000Z", seq: 2)
        try TransactionStore.save(existing1, in: context)
        try TransactionStore.save(existing2, in: context)

        let invalidJSON = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-10T00:00:00.000Z","transactions":[
          {"id":"tx_bad","type":"deposit","amount":-1,"note":"","dateISO":"2026-08-10T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(invalidJSON, into: context)

        XCTAssertEqual(result, .failure(.invalidTransactionRecord))
        try assertUnchanged(context, expected: [existing1, existing2])

        let restored = try TransactionStore.fetchAll(from: context)
        let r1 = restored.first { $0.id == "keep1" }
        XCTAssertEqual(r1?.amount, 500_000)
        XCTAssertEqual(r1?.note, "راتب")
        XCTAssertEqual(r1?.dateISO, existing1.dateISO)
        let r2 = restored.first { $0.id == "keep2" }
        XCTAssertEqual(r2?.amount, 100_000)
        XCTAssertEqual(r2?.note, "مصاريف")
    }

    // MARK: - Duplicate IDs rejected

    @MainActor
    func test_import_duplicateIDsWithinPayload_isRejected() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_dup","type":"deposit","amount":500000,"note":"أول","dateISO":"2026-08-01T00:00:00.000Z","seq":1},
          {"id":"tx_dup","type":"withdraw","amount":100000,"note":"ثانٍ","dateISO":"2026-08-02T00:00:00.000Z","seq":2}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        XCTAssertEqual(result, .failure(.duplicateTransactionID))
        try assertUnchanged(context, expected: [existing])
    }

    // MARK: - Malformed JSON rejected

    @MainActor
    func test_import_malformedJSON_isRejected() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let garbage = "{ this is not valid JSON at all".data(using: .utf8)!

        let result = BackupService.importBackup(garbage, into: context)

        XCTAssertEqual(result, .failure(.malformedJSON))
        try assertUnchanged(context, expected: [existing])
    }

    @MainActor
    func test_import_emptyData_isRejectedAsMalformed() throws {
        let context = try makeContext()
        let result = BackupService.importBackup(Data(), into: context)
        XCTAssertEqual(result, .failure(.malformedJSON))
    }

    // MARK: - Successful import atomically replaces existing data

    @MainActor
    func test_import_successfulImport_atomicallyReplacesExistingData() throws {
        let context = try makeContext()
        let oldData = tx(id: "old", type: .deposit, amount: 999_000, dateISOString: "2026-07-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(oldData, in: context)

        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"new_1","type":"deposit","amount":700000,"note":"جديد","dateISO":"2026-08-10T00:00:00.000Z","seq":10}
        ]}
        """.data(using: .utf8)!

        let result = BackupService.importBackup(json, into: context)

        guard case .success(let count) = result else {
            return XCTFail("توقعت نجاح الاستيراد، النتيجة: \(result)")
        }
        XCTAssertEqual(count, 1)

        let final = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(final.map(\.id), ["new_1"]) // "old" اختفى تمامًا؛ استبدال كامل، وليس دمجًا
    }
}
