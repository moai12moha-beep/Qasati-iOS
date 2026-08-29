import XCTest

final class DepositFormUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        tap(app.tabBars.buttons["tab.addTransaction"])
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func waitForText(_ text: String, timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    /// نقر بالإحداثيات بدل XCUIElement.tap() الافتراضي — أزرار شريط التبويب في بيئة CI
    /// هذه (macos-14 Simulator) تُظهر أحيانًا فشل "scroll to visible" (AXAction) غير
    /// مرتبط بأي سلوك إنتاجي فعلي؛ النقر بالإحداثيات يتجاوز تلك الخطوة تمامًا.
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 20)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_validDeposit_submitSucceeds_fieldsClear() {
        let amountField = app.textFields["المبلغ"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 20))
        amountField.tap()
        amountField.typeText("500000")

        let noteField = app.textFields["الملاحظات، اختياري"]
        noteField.tap()
        noteField.typeText("ملاحظة اختبار")

        app.buttons["إضافة إلى القاصة"].tap()

        // النجاح يُظهَر بتفريغ الحقول فقط — لا شارة/رسالة نجاح منفصلة في التصميم الحالي.
        XCTAssertNotEqual(amountField.value as? String, "500000")
        XCTAssertFalse(app.staticTexts["يرجى إدخال مبلغ صحيح."].exists)
    }

    func test_invalidAmount_showsValidationMessage() {
        app.buttons["إضافة إلى القاصة"].tap()

        XCTAssertTrue(app.staticTexts["يرجى إدخال مبلغ صحيح."].waitForExistence(timeout: 20))
    }

    func test_quickSalary_prefillsNote_createsNoTransactionBeforeSubmit() {
        let noteField = app.textFields["الملاحظات، اختياري"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 20))
        XCTAssertEqual((noteField.value as? String) ?? "", "")

        app.buttons["⚡ إضافة راتب سريع"].tap()

        let noteValue = (noteField.value as? String) ?? ""
        XCTAssertTrue(noteValue.hasPrefix("راتب شهر"), "Expected quick-salary prefill, got: \(noteValue)")

        // لم يُنشَأ أي عملية بعد — السجل ما زال فارغًا تمامًا.
        tap(app.tabBars.buttons["tab.history"])
        XCTAssertTrue(waitForText("القاصة فارغة"))

        // العودة والإرسال الفعلي هو من يُنشئ العملية.
        tap(app.tabBars.buttons["tab.addTransaction"])
        let amountField = app.textFields["المبلغ"]
        amountField.tap()
        amountField.typeText("300000")
        app.buttons["إضافة إلى القاصة"].tap()

        tap(app.tabBars.buttons["tab.history"])
        XCTAssertFalse(waitForText("القاصة فارغة", timeout: 3))
    }
}
