import Foundation
import XCTest
import SwiftData
@testable import QasatiTransactionFormsFeature
@testable import QasatiPersistence
@testable import QasatiDomain

final class QuickSalaryPrefillTests: XCTestCase {

    // نفس نمط العزل المُستخدَم في بقية اختبارات هذا الهدف: ملف تخزين حقيقي فريد لكل اختبار.
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickSalaryPrefillTests-\(UUID().uuidString)")
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

    // (a) و(b): يملأ الملاحظة، ولا يلمس amountText
    @MainActor
    func test_applyQuickSalaryPrefill_setsNote_leavesAmountUntouched() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)
        viewModel.amountText = "شيء كتبه المستخدم مسبقًا"

        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")

        XCTAssertEqual(viewModel.noteText, "راتب شهر أغسطس")
        XCTAssertEqual(viewModel.amountText, "شيء كتبه المستخدم مسبقًا")
    }

    // (c): يطلب التركيز عبر زيادة العدّاد، وفي كل ضغطة على حدة
    @MainActor
    func test_applyQuickSalaryPrefill_incrementsFocusSignalEveryTime() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)

        XCTAssertEqual(viewModel.focusAmountFieldSignal, 0)
        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")
        XCTAssertEqual(viewModel.focusAmountFieldSignal, 1)
        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")
        XCTAssertEqual(viewModel.focusAmountFieldSignal, 2)
    }

    // (d) و(e): لا يُنشئ عملية ولا يُخزّن أي شيء إطلاقًا
    @MainActor
    func test_applyQuickSalaryPrefill_persistsNothing() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)

        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertTrue(all.isEmpty)
        XCTAssertFalse(viewModel.didSaveSuccessfully)
    }

    // (f): بعد التعبئة التلقائية، الإرسال اليدوي العادي يبقى يمر عبر TransactionService.add
    // كما هو دون تغيير — لا مسار جانبي يتحايل على القواعد الموجودة
    @MainActor
    func test_afterQuickSalaryPrefill_normalSubmitStillUsesExistingValidatedFlow() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)

        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")
        XCTAssertTrue(try TransactionStore.fetchAll(from: context).isEmpty) // لم يُحفَظ شيء بعد

        viewModel.amountText = "500,000" // المستخدم يكتب المبلغ يدويًا كما في السلوك المعتمد
        viewModel.submit()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.didSaveSuccessfully)

        let all = try TransactionStore.fetchAll(from: context)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.amount, 500_000)
        XCTAssertEqual(all.first?.note, "راتب شهر أغسطس")
        XCTAssertEqual(all.first?.type, .deposit)
    }

    // تحقّق إضافي: التعبئة التلقائية بلا إدخال مبلغ لاحقًا، ثم إرسال — يجب أن يُرفَض
    // بنفس رسالة الخطأ المعتادة (لا مسار خاص يتجاوز التحقق لمجرد أن راتب سريع استُخدم)
    @MainActor
    func test_quickSalaryPrefill_withoutEnteringAmount_submitStillFailsNormally() throws {
        let context = try makeContext()
        let viewModel = TransactionFormViewModel(type: .deposit, context: context)

        viewModel.applyQuickSalaryPrefill(monthLabel: "راتب شهر أغسطس")
        viewModel.submit()

        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.errorMessage, "يرجى إدخال مبلغ صحيح.")
        XCTAssertTrue(try TransactionStore.fetchAll(from: context).isEmpty)
    }
}
