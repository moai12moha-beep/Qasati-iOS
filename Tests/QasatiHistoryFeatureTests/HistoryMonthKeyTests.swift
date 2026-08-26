import Foundation
import XCTest
@testable import QasatiHistoryFeature

final class HistoryMonthKeyTests: XCTestCase {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = formatter.date(from: iso) else {
            XCTFail("تعذر تحليل تاريخ الاختبار: \(iso)")
            return Date(timeIntervalSince1970: 0)
        }
        return d
    }

    func test_key_producesYYYYDashMM() {
        let key = HistoryMonthKey.key(for: date("2026-08-15T00:00:00.000Z"), calendar: utcCalendar)
        XCTAssertEqual(key, "2026-08")
    }

    func test_key_padsSingleDigitMonth() {
        let key = HistoryMonthKey.key(for: date("2026-01-05T00:00:00.000Z"), calendar: utcCalendar)
        XCTAssertEqual(key, "2026-01")
    }

    func test_key_december() {
        let key = HistoryMonthKey.key(for: date("2026-12-31T23:59:59.000Z"), calendar: utcCalendar)
        XCTAssertEqual(key, "2026-12")
    }

    func test_label_roundTripsToArabicMonthAndYear() {
        let key = HistoryMonthKey.key(for: date("2026-08-15T00:00:00.000Z"), calendar: utcCalendar)
        XCTAssertEqual(HistoryMonthLabel.label(forKey: key), "أغسطس 2026")
    }

    func test_label_includesYear_unlikeQuickSalaryMonthLabel() {
        // بعكس QuickSalaryMonthLabel (Phase 6) الذي يحذف السنة عمدًا، هذا التسمية
        // مخصَّصة لقائمة اختيار الشهر ويجب أن تتضمن السنة صراحةً.
        XCTAssertEqual(HistoryMonthLabel.label(forKey: "2026-01"), "يناير 2026")
    }

    func test_label_invalidKey_returnsKeyUnchanged() {
        XCTAssertEqual(HistoryMonthLabel.label(forKey: "not-a-key"), "not-a-key")
    }
}
