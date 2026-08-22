import Foundation
import XCTest
@testable import QasatiTransactionFormsFeature

final class QuickSalaryMonthLabelTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = formatter.date(from: iso) else {
            XCTFail("تعذر تحليل تاريخ الاختبار: \(iso)")
            return Date(timeIntervalSince1970: 0)
        }
        return d
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func test_current_august_producesExpectedArabicLabel() {
        let label = QuickSalaryMonthLabel.current(
            date: date("2026-08-15T00:00:00.000Z"),
            calendar: utcCalendar
        )
        XCTAssertEqual(label, "راتب شهر أغسطس")
    }

    func test_current_january_producesExpectedArabicLabel() {
        let label = QuickSalaryMonthLabel.current(
            date: date("2026-01-01T00:00:00.000Z"),
            calendar: utcCalendar
        )
        XCTAssertEqual(label, "راتب شهر يناير")
    }

    func test_current_december_producesExpectedArabicLabel() {
        let label = QuickSalaryMonthLabel.current(
            date: date("2026-12-31T23:59:59.000Z"),
            calendar: utcCalendar
        )
        XCTAssertEqual(label, "راتب شهر ديسمبر")
    }

    func test_current_doesNotIncludeYear() {
        let label = QuickSalaryMonthLabel.current(
            date: date("2026-08-15T00:00:00.000Z"),
            calendar: utcCalendar
        )
        XCTAssertFalse(label.contains("2026"))
    }
}
