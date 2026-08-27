import Foundation
import XCTest
import SwiftData
@testable import QasatiSettingsFeature
@testable import QasatiBackupService
@testable import QasatiPersistence
@testable import QasatiDomain

final class SettingsViewModelTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsViewModelTests-\(UUID().uuidString)")
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

    // MARK: - Export

    @MainActor
    func test_exportFile_writesFileThatBackupServiceCanReadBack() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T08:00:00.000Z", seq: 1)
        try TransactionStore.save(t1, in: context)

        let viewModel = SettingsViewModel(context: context)
        let url = viewModel.exportFile()

        XCTAssertNotNil(url)
        XCTAssertFalse(viewModel.isError)
        XCTAssertEqual(viewModel.statusMessage, "تم تصدير نسخة احتياطية بنجاح.")

        let data = try Data(contentsOf: url!)
        let result = BackupService.importBackup(data, into: context)
        guard case .success = result else {
            return XCTFail("الملف المُصدَّر يجب أن يكون قابلاً للاستيراد عبر BackupService نفسها")
        }
        try? FileManager.default.removeItem(at: url!)
    }

    // MARK: - Import success

    @MainActor
    func test_importData_validBackup_succeedsAndReportsCount() throws {
        let context = try makeContext()
        let json = """
        {"app":"qasati","version":1,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_1","type":"deposit","amount":500000,"note":"راتب","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let viewModel = SettingsViewModel(context: context)
        viewModel.importData(json)

        XCTAssertFalse(viewModel.isError)
        XCTAssertNil(viewModel.lastImportError)
        XCTAssertEqual(viewModel.statusMessage, "تم استيراد 1 عملية بنجاح.")

        let stored = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(stored.map(\.id), ["tx_1"])
    }

    // MARK: - Import failure: generic user message, specific error kept internally

    @MainActor
    func test_importData_invalidBackup_showsGenericMessage_keepsSpecificErrorInternally() throws {
        let context = try makeContext()
        let existing = tx(id: "keep", type: .deposit, amount: 100_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        try TransactionStore.save(existing, in: context)

        let malformed = "not json at all".data(using: .utf8)!

        let viewModel = SettingsViewModel(context: context)
        viewModel.importData(malformed)

        XCTAssertTrue(viewModel.isError)
        XCTAssertEqual(viewModel.statusMessage, "ملف غير صالح. يرجى اختيار نسخة احتياطية صحيحة من قاصتي.")
        XCTAssertEqual(viewModel.lastImportError, .malformedJSON) // السبب التقني الدقيق محفوظ داخليًا فقط

        // البيانات الحالية لم تُلمَس (BackupService نفسها مسؤولة عن هذا الضمان، ونتحقق هنا من عدم كسره عبر الواجهة)
        XCTAssertEqual(try TransactionStore.fetchAll(from: context).map(\.id), ["keep"])
    }

    @MainActor
    func test_importData_unsupportedVersion_showsSameGenericMessage() throws {
        let context = try makeContext()
        let json = """
        {"app":"qasati","version":99,"exportedAt":"2026-08-01T00:00:00.000Z","transactions":[
          {"id":"tx_1","type":"deposit","amount":500000,"note":"","dateISO":"2026-08-01T00:00:00.000Z","seq":1}
        ]}
        """.data(using: .utf8)!

        let viewModel = SettingsViewModel(context: context)
        viewModel.importData(json)

        XCTAssertTrue(viewModel.isError)
        XCTAssertEqual(viewModel.statusMessage, "ملف غير صالح. يرجى اختيار نسخة احتياطية صحيحة من قاصتي.")
        XCTAssertEqual(viewModel.lastImportError, .unsupportedVersion)
    }

    @MainActor
    func test_reportImportReadFailure_showsGenericMessage() throws {
        let context = try makeContext()
        let viewModel = SettingsViewModel(context: context)

        viewModel.reportImportReadFailure()

        XCTAssertTrue(viewModel.isError)
        XCTAssertEqual(viewModel.statusMessage, "ملف غير صالح. يرجى اختيار نسخة احتياطية صحيحة من قاصتي.")
        XCTAssertNil(viewModel.lastImportError)
    }

    // MARK: - Wipe

    @MainActor
    func test_wipeAllData_emptiesStoreAndReportsSuccess() throws {
        let context = try makeContext()
        let t1 = tx(id: "t1", type: .deposit, amount: 500_000, dateISOString: "2026-08-01T00:00:00.000Z", seq: 1)
        let t2 = tx(id: "t2", type: .withdraw, amount: 100_000, dateISOString: "2026-08-02T00:00:00.000Z", seq: 2)
        try TransactionStore.save(t1, in: context)
        try TransactionStore.save(t2, in: context)

        let viewModel = SettingsViewModel(context: context)
        viewModel.wipeAllData()

        XCTAssertFalse(viewModel.isError)
        XCTAssertEqual(viewModel.statusMessage, "تم حذف جميع البيانات من هذا الجهاز.")
        XCTAssertTrue(try TransactionStore.fetchAll(from: context).isEmpty)
    }

    // MARK: - clearStatus

    @MainActor
    func test_clearStatus_resetsMessageAndErrorFlag() throws {
        let context = try makeContext()
        let viewModel = SettingsViewModel(context: context)
        viewModel.reportImportReadFailure()
        XCTAssertNotNil(viewModel.statusMessage)

        viewModel.clearStatus()

        XCTAssertNil(viewModel.statusMessage)
        XCTAssertFalse(viewModel.isError)
    }
}
