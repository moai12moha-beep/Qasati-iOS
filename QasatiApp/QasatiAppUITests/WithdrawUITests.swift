import XCTest

final class WithdrawUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        app.tabBars.buttons["tab.addTransaction"].tap()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func test_validWithdrawal_afterDeposit_succeeds() {
        let amountField = app.textFields["المبلغ"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("500000")
        app.buttons["إضافة إلى القاصة"].tap()

        app.buttons["سحب"].tap() // مقطع السحب في مُقسِّم النوع

        let withdrawAmountField = app.textFields["المبلغ"]
        XCTAssertTrue(withdrawAmountField.waitForExistence(timeout: 5))
        withdrawAmountField.tap()
        withdrawAmountField.typeText("200000")
        app.buttons["سحب من القاصة"].tap()

        XCTAssertFalse(app.staticTexts["الرصيد غير كافٍ لإتمام عملية السحب."].exists)
        XCTAssertNotEqual(withdrawAmountField.value as? String, "200000")
    }
}
