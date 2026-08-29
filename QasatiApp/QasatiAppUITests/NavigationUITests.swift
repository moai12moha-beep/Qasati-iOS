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
    private func waitForText(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    func test_launch_dashboardTabIsVisibleAndSelected() {
        let dashboardTab = app.tabBars.buttons["tab.dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardTab.isSelected)
        XCTAssertTrue(waitForText("الرصيد"))
    }

    func test_navigateAllFourTabs() {
        let dashboardTab = app.tabBars.buttons["tab.dashboard"]
        let addTab = app.tabBars.buttons["tab.addTransaction"]
        let historyTab = app.tabBars.buttons["tab.history"]
        let settingsTab = app.tabBars.buttons["tab.settings"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5))

        addTab.tap()
        XCTAssertTrue(app.buttons["إضافة إلى القاصة"].waitForExistence(timeout: 5))
        XCTAssertTrue(addTab.isSelected)

        historyTab.tap()
        XCTAssertTrue(historyTab.isSelected)
        XCTAssertTrue(waitForText("سجل"))

        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)
        XCTAssertTrue(app.switches["🌙 الوضع الليلي"].waitForExistence(timeout: 5))

        dashboardTab.tap()
        XCTAssertTrue(dashboardTab.isSelected)
    }
}
