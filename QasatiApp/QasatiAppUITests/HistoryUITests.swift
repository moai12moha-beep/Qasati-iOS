import XCTest

final class HistoryUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func waitForText(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    private func addDeposit(amount: String, note: String) {
        app.tabBars.buttons["tab.addTransaction"].tap()
        let amountField = app.textFields["المبلغ"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText(amount)
        let noteField = app.textFields["الملاحظات، اختياري"]
        noteField.tap()
        noteField.typeText(note)
        app.buttons["إضافة إلى القاصة"].tap()
    }

    /// يمسح نص حقل نصي حالي عبر مفاتيح حذف فعلية — لا زر "مسح" مُهيَّأ على هذه الحقول.
    private func clearText(in field: XCUIElement) {
        guard let current = field.value as? String, !current.isEmpty else { return }
        field.tap()
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        field.typeText(deletes)
    }

    func test_addedTransaction_appearsInHistory() {
        addDeposit(amount: "500000", note: "ملاحظة اختبار السجل")

        app.tabBars.buttons["tab.history"].tap()

        XCTAssertTrue(waitForText("ملاحظة اختبار السجل"))
    }

    func test_search_filtersToMatchingNoteOnly() {
        addDeposit(amount: "500000", note: "راتب آب")
        app.tabBars.buttons["tab.addTransaction"].tap()
        addDeposit(amount: "100000", note: "مصاريف شخصية")

        app.tabBars.buttons["tab.history"].tap()
        let searchField = app.textFields["بحث في الملاحظات"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("راتب")

        XCTAssertTrue(waitForText("راتب آب"))
        XCTAssertFalse(waitForText("مصاريف شخصية", timeout: 2))
    }

    func test_editTransaction_updatedAmountVisible() {
        addDeposit(amount: "500000", note: "قبل التعديل")
        app.tabBars.buttons["tab.history"].tap()
        XCTAssertTrue(waitForText("قبل التعديل"))

        app.buttons["تعديل العملية"].firstMatch.tap()

        let amountField = app.textFields["المبلغ"].firstMatch
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        clearText(in: amountField)
        amountField.typeText("750000")
        app.buttons["حفظ التعديلات"].tap()

        XCTAssertTrue(waitForText("750"))
    }

    func test_deleteConfirmation_cancelKeepsTransaction_confirmRemovesIt() {
        addDeposit(amount: "500000", note: "للحذف")
        app.tabBars.buttons["tab.history"].tap()
        XCTAssertTrue(waitForText("للحذف"))

        app.buttons["حذف العملية"].firstMatch.tap()
        let cancelButton = app.buttons["إلغاء"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        XCTAssertTrue(waitForText("للحذف")) // أُلغي — ما زالت موجودة

        app.buttons["حذف العملية"].firstMatch.tap()
        let confirmButton = app.buttons["حذف العملية"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        XCTAssertTrue(waitForText("القاصة فارغة"))
    }
}
