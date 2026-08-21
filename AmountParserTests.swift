import XCTest
@testable import QasatiDomain

final class AmountParserTests: XCTestCase {

    // MARK: - parse

    func test_parse_plainDigits() {
        XCTAssertEqual(AmountParser.parse("500000"), 500_000)
    }

    func test_parse_withThousandsCommas_stripsCommas() {
        XCTAssertEqual(AmountParser.parse("500,000"), 500_000)
    }

    func test_parse_withSpacesAndNonDigitCharacters_stripsThem() {
        XCTAssertEqual(AmountParser.parse(" 1,234,567 د.ع "), 1_234_567)
    }

    func test_parse_negativeSign_isStrippedNotInterpreted() {
        // يطابق سلوك المصدر: parseAmountInput يحذف كل شيء عدا الأرقام، فإشارة "-" تُحذف
        // ولا يمكن إنتاج رقم سالب عبر هذا المسار إطلاقًا.
        XCTAssertEqual(AmountParser.parse("-500000"), 500_000)
    }

    func test_parse_decimalPoint_isStrippedNotTreatedAsFraction() {
        // "500.50" -> يُحذف "." فتُدمَج الأرقام: "50050"
        XCTAssertEqual(AmountParser.parse("500.50"), 50_050)
    }

    func test_parse_emptyString_returnsNil() {
        XCTAssertNil(AmountParser.parse(""))
    }

    func test_parse_onlyNonDigitCharacters_returnsNil() {
        XCTAssertNil(AmountParser.parse("د.ع ,, "))
    }

    func test_parse_arabicIndicDigits_areNotSupported_returnsNilOrPartial() {
        // ٥٠٠ (خمسمائة بالأرقام العربية الهندية) لا تُعامَل كأرقام في المصدر (الفلتر [^\d] يقبل ASCII فقط)
        // فتُحذف بالكامل، تمامًا كما هنا. هذا غياب مُنقول عمدًا وليس افتراضًا جديدًا.
        XCTAssertNil(AmountParser.parse("٥٠٠"))
    }

    // MARK: - isValidAmount

    func test_isValidAmount_positiveInteger_isValid() {
        XCTAssertTrue(AmountParser.isValidAmount(1))
        XCTAssertTrue(AmountParser.isValidAmount(500_000))
    }

    func test_isValidAmount_zero_isInvalid() {
        XCTAssertFalse(AmountParser.isValidAmount(0))
    }

    func test_isValidAmount_negative_isInvalid() {
        XCTAssertFalse(AmountParser.isValidAmount(-1))
    }
}
