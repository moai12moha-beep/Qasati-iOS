import Foundation
import XCTest
@testable import QasatiSettingsFeature

final class AppPreferencesTests: XCTestCase {

    // نفس فلسفة العزل المُستخدَمة لـ SwiftData في بقية المشروع، مطبَّقة هنا على
    // UserDefaults: مجموعة (suite) معزولة فريدة لكل اختبار، وليس .standard أبدًا.
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AppPreferencesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    @MainActor
    func test_init_noStoredPreferences_defaultsToNilThemeAndVisibleBalance() {
        let prefs = AppPreferences(defaults: defaults)

        XCTAssertNil(prefs.colorScheme)
        XCTAssertFalse(prefs.isBalanceHidden)
    }

    // MARK: - Correction: first toggle from "no preference" must follow the actual
    // current system appearance and switch to its opposite (not always "dark").

    @MainActor
    func test_toggleTheme_noPreference_systemLight_firstToggleSetsDark() {
        let prefs = AppPreferences(defaults: defaults)
        XCTAssertNil(prefs.colorScheme)

        prefs.toggleTheme(systemAppearance: .light)

        XCTAssertEqual(prefs.colorScheme, .dark)
    }

    @MainActor
    func test_toggleTheme_noPreference_systemDark_firstToggleSetsLight() {
        let prefs = AppPreferences(defaults: defaults)
        XCTAssertNil(prefs.colorScheme)

        prefs.toggleTheme(systemAppearance: .dark)

        XCTAssertEqual(prefs.colorScheme, .light)
    }

    @MainActor
    func test_toggleTheme_flipsBackAndForth_ignoringSystemAppearanceOnceExplicit() {
        let prefs = AppPreferences(defaults: defaults)

        prefs.toggleTheme(systemAppearance: .light) // nil -> opposite of light -> dark
        XCTAssertEqual(prefs.colorScheme, .dark)

        // systemAppearance يُتجاهَل تمامًا بمجرد وجود تفضيل صريح — يُمرَّر عمدًا قيمًا
        // مختلفة هنا لإثبات أنها لا تؤثر إطلاقًا بعد أول ضغطة.
        prefs.toggleTheme(systemAppearance: .dark) // dark -> light (عادي، بصرف النظر عن النظام)
        XCTAssertEqual(prefs.colorScheme, .light)

        prefs.toggleTheme(systemAppearance: .light) // light -> dark
        XCTAssertEqual(prefs.colorScheme, .dark)
    }

    @MainActor
    func test_toggleTheme_persistsAcrossNewInstance_sameDefaultsSuite() {
        let first = AppPreferences(defaults: defaults)
        first.toggleTheme(systemAppearance: .light) // -> dark

        let second = AppPreferences(defaults: defaults)

        XCTAssertEqual(second.colorScheme, .dark)
    }

    @MainActor
    func test_togglePrivacy_flipsAndPersistsAcrossNewInstance() {
        let first = AppPreferences(defaults: defaults)
        XCTAssertFalse(first.isBalanceHidden)

        first.togglePrivacy()
        XCTAssertTrue(first.isBalanceHidden)

        let second = AppPreferences(defaults: defaults)
        XCTAssertTrue(second.isBalanceHidden)

        second.togglePrivacy()
        XCTAssertFalse(second.isBalanceHidden)

        let third = AppPreferences(defaults: defaults)
        XCTAssertFalse(third.isBalanceHidden)
    }

    @MainActor
    func test_separateDefaultsSuites_doNotShareState() {
        let otherSuiteName = "AppPreferencesTests-other-\(UUID().uuidString)"
        let otherDefaults = UserDefaults(suiteName: otherSuiteName)!
        defer { otherDefaults.removePersistentDomain(forName: otherSuiteName) }

        let prefsA = AppPreferences(defaults: defaults)
        prefsA.toggleTheme(systemAppearance: .light)
        prefsA.togglePrivacy()

        let prefsB = AppPreferences(defaults: otherDefaults)

        XCTAssertNil(prefsB.colorScheme)
        XCTAssertFalse(prefsB.isBalanceHidden)
    }
}
