import XCTest

final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func test_themeToggle_isReachableAndTogglable() {
        let themeToggle = app.switches["🌙 الوضع الليلي"]
        XCTAssertTrue(themeToggle.waitForExistence(timeout: 5))

        let initialValue = themeToggle.value as? String
        themeToggle.tap()
        let toggledValue = themeToggle.value as? String

        XCTAssertNotEqual(initialValue, toggledValue)
    }

    func test_privacyToggle_isReachableAndTogglable() {
        let privacyToggle = app.switches["👁️ إخفاء الرصيد"]
        XCTAssertTrue(privacyToggle.waitForExistence(timeout: 5))

        let initialValue = privacyToggle.value as? String
        privacyToggle.tap()
        let toggledValue = privacyToggle.value as? String

        XCTAssertNotEqual(initialValue, toggledValue)
    }

    /// يتحقق من إمكانية الوصول إلى نقاط الدخول الثلاث فقط (تصدير/استيراد/مسح) — لا يُكمل
    /// تدفق ملف نظام كامل، ولا يُنفّذ مسحًا فعليًا (يُلغي عند تأكيد المسح الأول).
    func test_backupImportWipeEntryPoints_areReachable() {
        XCTAssertTrue(app.buttons["⬇️ تصدير"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["⬆️ استيراد"].waitForExistence(timeout: 5))

        let wipeButton = app.buttons["🗑️ مسح جميع البيانات"]
        XCTAssertTrue(wipeButton.waitForExistence(timeout: 5))
        wipeButton.tap()

        XCTAssertTrue(app.buttons["متابعة"].waitForExistence(timeout: 5))
        app.buttons["إلغاء"].tap()
    }
}
