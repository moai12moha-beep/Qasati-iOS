import XCTest

final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        tap(app.tabBars.buttons["tab.settings"])
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// نقر بالإحداثيات بدل XCUIElement.tap() الافتراضي — أزرار شريط التبويب ومفاتيح
    /// التبديل (Toggle) في بيئة CI هذه (macos-14 Simulator) تُظهر أحيانًا فشل صامت أو
    /// "scroll to visible" (AXAction) غير مرتبط بأي سلوك إنتاجي فعلي؛ النقر بالإحداثيات
    /// يتجاوز تلك الخطوة تمامًا.
    private func tap(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_themeToggle_isReachableAndTogglable() {
        let themeToggle = app.switches["🌙 الوضع الليلي"]
        XCTAssertTrue(themeToggle.waitForExistence(timeout: 10))

        let initialValue = themeToggle.value as? String
        tap(themeToggle)
        let toggledValue = themeToggle.value as? String

        XCTAssertNotEqual(initialValue, toggledValue)
    }

    func test_privacyToggle_isReachableAndTogglable() {
        let privacyToggle = app.switches["👁️ إخفاء الرصيد"]
        XCTAssertTrue(privacyToggle.waitForExistence(timeout: 10))

        let initialValue = privacyToggle.value as? String
        tap(privacyToggle)
        let toggledValue = privacyToggle.value as? String

        XCTAssertNotEqual(initialValue, toggledValue)
    }

    /// يتحقق من إمكانية الوصول إلى نقاط الدخول الثلاث فقط (تصدير/استيراد/مسح) — لا يُكمل
    /// تدفق ملف نظام كامل، ولا يُنفّذ مسحًا فعليًا (يُلغي عند تأكيد المسح الأول).
    func test_backupImportWipeEntryPoints_areReachable() {
        XCTAssertTrue(app.buttons["⬇️ تصدير"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["⬆️ استيراد"].waitForExistence(timeout: 10))

        let wipeButton = app.buttons["🗑️ مسح جميع البيانات"]
        XCTAssertTrue(wipeButton.waitForExistence(timeout: 10))
        wipeButton.tap()

        XCTAssertTrue(app.buttons["متابعة"].waitForExistence(timeout: 10))
        app.buttons["إلغاء"].tap()
    }
}
