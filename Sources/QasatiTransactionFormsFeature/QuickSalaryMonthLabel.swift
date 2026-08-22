import Foundation

/// يولّد نص تعبئة ملاحظة "راتب سريع" — تنسيق نصي عرضي بحت، بلا أي منطق مالي وبلا أي
/// اتصال بـ TransactionService/TransactionStore. يطابق منطق
/// `monthLabel(monthKey(new Date().toISOString())).split(" ")[0]` في qasati-standalone_2.html:
/// اسم الشهر العربي الحالي فقط، بلا السنة.
public enum QuickSalaryMonthLabel {

    private static let arabicMonthNames = [
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ]

    /// يطابق "راتب شهر <اسم الشهر>" بالضبط. `date`/`calendar` قابلان للحقن عمدًا لجعل
    /// الاختبار حتميًا، بنفس أسلوب LedgerCalculator.summary(now:calendar:) في Phase 1.
    public static func current(date: Date = Date(), calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        let name = arabicMonthNames[month - 1]
        return "راتب شهر \(name)"
    }
}
