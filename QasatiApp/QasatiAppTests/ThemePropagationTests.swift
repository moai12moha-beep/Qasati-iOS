import XCTest
@testable import QasatiApp
import QasatiSettingsFeature

/// يختبر نقطة الوصل الفعلية بين AppPreferences (SwiftPM، غير مُعدَّلة هنا) وmappedColorScheme
/// (طبقة التطبيق) — تمامًا كما يستخدمها RootView.body فعليًا عبر
/// .preferredColorScheme(mappedColorScheme(for: preferences.colorScheme)). لا يختبر حقن
/// SwiftUI environment نفسه (ذلك يتطلب اختبار واجهة حقيقي، مؤجَّل)، بل يثبت أن قيمة
/// colorScheme الناتجة عن AppPreferences (بما فيها قاعدة "أول ضغطة تتبع مظهر النظام
/// الفعلي" المُعتمَدة في Phase 10) تُترجَم دومًا إلى ColorScheme الصحيح عند القمة.
@MainActor
final class ThemePropagationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "ThemePropagationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func test_noStoredPreference_mapsToNil_followsSystem() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertNil(mappedColorScheme(for: preferences.colorScheme))
    }

    func test_afterToggleFromSystemLight_mapsToDark() {
        let preferences = AppPreferences(defaults: defaults)

        preferences.toggleTheme(systemAppearance: .light)

        XCTAssertEqual(mappedColorScheme(for: preferences.colorScheme), .dark)
    }

    func test_afterToggleFromSystemDark_mapsToLight() {
        let preferences = AppPreferences(defaults: defaults)

        preferences.toggleTheme(systemAppearance: .dark)

        XCTAssertEqual(mappedColorScheme(for: preferences.colorScheme), .light)
    }

    func test_secondToggle_ignoresSystemAppearance_mapsToOpposite() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.toggleTheme(systemAppearance: .light) // -> dark

        preferences.toggleTheme(systemAppearance: .light) // dark -> light (النظام يُتجاهَل الآن)

        XCTAssertEqual(mappedColorScheme(for: preferences.colorScheme), .light)
    }

    func test_persistsAcrossNewAppPreferencesInstance_sameDefaultsSuite() {
        let first = AppPreferences(defaults: defaults)
        first.toggleTheme(systemAppearance: .light) // -> dark

        let second = AppPreferences(defaults: defaults)

        XCTAssertEqual(mappedColorScheme(for: second.colorScheme), .dark)
    }
}
