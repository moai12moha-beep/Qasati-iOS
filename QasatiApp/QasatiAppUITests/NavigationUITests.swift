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
        // إحماء: أول استعلام عن شريط التبويبات يتم هنا (وليس داخل جسم الاختبار مباشرة) —
        // الاختبارات الأخرى التي تنقر تبويبًا داخل setUp لا تعاني من فشل حل العنصر الأول
        // بعد الإطلاق؛ هذا الاستعلام غير المُثبَت (تجاهل النتيجة) يمنح شجرة الوصول نفس
        // فرصة الاستقرار قبل بدء جسم الاختبار.
        _ = app.tabBars.buttons["tab.dashboard"].waitForExistence(timeout: 20)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// بحث بالاحتواء بدل تطابق دقيق — بعض النصوص مُجمَّعة عبر
    /// .accessibilityElement(children: .combine) (Phase 12)، فقد لا يكون نوع العنصر أو
    /// تسميته الدقيقة staticText مطابقًا حرفيًا للنص المرئي.
    private func waitForText(_ text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    /// نقر بالإحداثيات بدل XCUIElement.tap() الافتراضي — أزرار شريط التبويب في بيئة CI
    /// هذه (macos-14 Simulator) تُظهر أحيانًا فشل "scroll to visible" (AXAction) غير
    /// مرتبط بأي سلوك إنتاجي فعلي؛ النقر بالإحداثيات يتجاوز تلك الخطوة تمامًا.
    private func tap(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_launch_dashboardTabIsVisibleAndSelected() {
        // استعلام بالموضع بدل المُعرِّف لتبويب "الرئيسية" تحديدًا: تبيَّن عبر عدة تشغيلات CI
        // حقيقية أن الاستعلام بمعرِّف التبويب الافتراضي/المُحدَّد مسبقًا تحديدًا (وليس بقية
        // التبويبات) لا يُحل بشكل موثوق فور الإطلاق، رغم أن شريط التبويبات نفسه موجود.
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 20))
        XCTAssertTrue(dashboardTab.isSelected)
        XCTAssertTrue(waitForText("الرصيد"))
    }

    func test_navigateAllFourTabs() {
        let dashboardTab = app.tabBars.buttons.element(boundBy: 0)
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
