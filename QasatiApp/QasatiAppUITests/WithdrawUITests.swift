import XCTest

final class WithdrawUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        Thread.sleep(forTimeInterval: 2) // مهلة استقرار قصيرة بعد الإطلاق، راجع NavigationUITests
        tap(app.tabBars.buttons["tab.addTransaction"])
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// نقر بالإحداثيات بدل XCUIElement.tap() الافتراضي — أزرار شريط التبويب في بيئة CI
    /// هذه (macos-14 Simulator) تُظهر أحيانًا فشل "scroll to visible" (AXAction) غير
    /// مرتبط بأي سلوك إنتاجي فعلي؛ النقر بالإحداثيات يتجاوز تلك الخطوة تمامًا.
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 20)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_validWithdrawal_afterDeposit_succeeds() {
        let amountField = app.textFields["المبلغ"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 20))
        amountField.tap()
        amountField.typeText("500000")
        app.buttons["إضافة إلى القاصة"].tap()

        app.buttons["سحب"].tap() // مقطع السحب في مُقسِّم النوع

        let withdrawAmountField = app.textFields["المبلغ"]
        XCTAssertTrue(withdrawAmountField.waitForExistence(timeout: 20))
        withdrawAmountField.tap()
        withdrawAmountField.typeText("200000")
        app.buttons["سحب من القاصة"].tap()

        XCTAssertFalse(app.staticTexts["الرصيد غير كافٍ لإتمام عملية السحب."].exists)
        XCTAssertNotEqual(withdrawAmountField.value as? String, "200000")
    }
}
