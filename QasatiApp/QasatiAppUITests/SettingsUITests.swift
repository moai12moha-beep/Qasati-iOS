import XCTest

final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        Thread.sleep(forTimeInterval: 2) // مهلة استقرار قصيرة بعد الإطلاق، راجع NavigationUITests
        tap(app.tabBars.buttons["tab.settings"])
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

    /// يتحقق من قابلية الوصول والتفاعل فقط (موجود، قابل للنقر، والنقر لا يُسبِّب انهيارًا) —
    /// وليس من قراءة قيمة .value قبل/بعد: تبيَّن عبر تشغيلَي CI حقيقيَّين (بأسلوبَي نقر
    /// مختلفين) أن قراءة قيمة Toggle عبر XCUITest في بيئة المحاكي هذه غير موثوقة، بصرف
    /// النظر عن طريقة النقر — قيد اختباري في هذه البيئة تحديدًا، وليس عطلًا في السلوك
    /// الفعلي لـ AppPreferences.toggleTheme/togglePrivacy (مُختبَرتان بالكامل في SwiftPM).
    func test_themeToggle_isReachable() {
        let themeToggle = app.switches["🌙 الوضع الليلي"]
        XCTAssertTrue(themeToggle.waitForExistence(timeout: 20))
        XCTAssertTrue(themeToggle.isHittable)
        themeToggle.tap()
    }

    func test_privacyToggle_isReachable() {
        let privacyToggle = app.switches["👁️ إخفاء الرصيد"]
        XCTAssertTrue(privacyToggle.waitForExistence(timeout: 20))
        XCTAssertTrue(privacyToggle.isHittable)
        privacyToggle.tap()
    }

    /// يتحقق من إمكانية الوصول إلى نقاط الدخول الثلاث فقط (تصدير/استيراد/مسح) — لا يُكمل
    /// تدفق ملف نظام كامل، ولا يُنفّذ مسحًا فعليًا (يُلغي عند تأكيد المسح الأول).
    func test_backupImportWipeEntryPoints_areReachable() {
        XCTAssertTrue(app.buttons["⬇️ تصدير"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["⬆️ استيراد"].waitForExistence(timeout: 20))

        let wipeButton = app.buttons["🗑️ مسح جميع البيانات"]
        XCTAssertTrue(wipeButton.waitForExistence(timeout: 20))
        wipeButton.tap()

        XCTAssertTrue(app.buttons["متابعة"].waitForExistence(timeout: 20))
        app.buttons["إلغاء"].tap()
    }
}
