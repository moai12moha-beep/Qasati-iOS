import XCTest
@testable import QasatiDashboardFeature

final class IQDFormatterTests: XCTestCase {

    func test_formatNumberOnly_addsThousandsSeparators() {
        XCTAssertEqual(IQDFormatter.formatNumberOnly(500_000), "500,000")
    }

    func test_formatNumberOnly_zero() {
        XCTAssertEqual(IQDFormatter.formatNumberOnly(0), "0")
    }

    func test_formatNumberOnly_smallValue_noSeparator() {
        XCTAssertEqual(IQDFormatter.formatNumberOnly(999), "999")
    }

    func test_formatIQD_appendsCurrencySuffix() {
        XCTAssertEqual(IQDFormatter.formatIQD(500_000), "500,000 د.ع")
    }

    func test_formatSignedMonthNet_positive_prependsPlus() {
        XCTAssertEqual(IQDFormatter.formatSignedMonthNet(400_000), "+400,000 د.ع")
    }

    func test_formatSignedMonthNet_negative_prependsMinusAndUsesAbsoluteValue() {
        XCTAssertEqual(IQDFormatter.formatSignedMonthNet(-400_000), "-400,000 د.ع")
    }

    func test_formatSignedMonthNet_zero_noSign() {
        XCTAssertEqual(IQDFormatter.formatSignedMonthNet(0), "0 د.ع")
    }
}
