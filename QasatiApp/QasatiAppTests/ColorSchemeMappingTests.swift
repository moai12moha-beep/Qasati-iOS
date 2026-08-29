import XCTest
import SwiftUI
@testable import QasatiApp
import QasatiSettingsFeature

/// يختبر mappedColorScheme(for:) بحتة — الدالة نفسها المُستخدَمة في
/// RootView.body عبر .preferredColorScheme(mappedColorScheme(for: preferences.colorScheme)).
final class ColorSchemeMappingTests: XCTestCase {

    func test_mappedColorScheme_light() {
        XCTAssertEqual(mappedColorScheme(for: .light), .light)
    }

    func test_mappedColorScheme_dark() {
        XCTAssertEqual(mappedColorScheme(for: .dark), .dark)
    }

    func test_mappedColorScheme_nil_followsSystem() {
        XCTAssertNil(mappedColorScheme(for: nil))
    }
}
