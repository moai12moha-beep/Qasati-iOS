import XCTest

/// كل اختبار يُطلق تطبيقًا جديدًا معزولًا عبر وسيطة "UI-TESTING" (تخزين في الذاكرة فقط،
/// يُضبَط في QasatiApp.init — راجع تعليقه) — لا اعتماد على بيانات خلَّفها اختبار سابق،
/// ولا حاجة لحساب Apple ID/iCloud أو جهاز فعلي.
final class NavigationUITests: XCTestCase {

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

    /// بحث بالاحتواء بدل تطابق دقيق — بعض النصوص مُجمَّعة عبر
    /// .accessibilityElement(children: .combine) (Phase 12)، فقد لا يكون نوع العنصر أو
    /// تسميته الدقيقة staticText مطابقًا حرفيًا للنص المرئي.
    private func waitForText(_ text: String, timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    /// نقر بالإحداثيات بدل XCUIElement.tap() الافتراضي — أزرار شريط التبويب في بيئة CI
    /// هذه (macos-14 Simulator) تُظهر أحيانًا فشل "scroll to visible" (AXAction) غير
    /// مرتبط بأي سلوك إنتاجي فعلي؛ النقر بالإحداثيات يتجاوز تلك الخطوة تمامًا.
    private func tap(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 20)
        element.tap()
    }

    func test_launch_dashboardTabIsVisibleAndSelected() {
        let dashboardTab = app.tabBars.buttons["tab.dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 20))
        XCTAssertTrue(dashboardTab.isSelected)
        XCTAssertTrue(waitForText("الرصيد"))
    }

    func test_navigateAllFourTabs() {
        let dashboardTab = app.tabBars.buttons["tab.dashboard"]
        let addTab = app.tabBars.buttons["tab.addTransaction"]
        let historyTab = app.tabBars.buttons["tab.history"]
        let settingsTab = app.tabBars.buttons["tab.settings"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 20))

        tap(addTab)
        XCTAssertTrue(app.buttons["إضافة إلى القاصة"].waitForExistence(timeout: 20))
        XCTAssertTrue(addTab.isSelected)

        tap(historyTab)
        XCTAssertTrue(historyTab.isSelected)
        XCTAssertTrue(waitForText("سجل"))

        tap(settingsTab)
        XCTAssertTrue(settingsTab.isSelected)
        XCTAssertTrue(app.switches["🌙 الوضع الليلي"].waitForExistence(timeout: 20))

        tap(dashboardTab)
        XCTAssertTrue(dashboardTab.isSelected)
    }
}
