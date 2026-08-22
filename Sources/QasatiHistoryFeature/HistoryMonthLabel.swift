/// يطابق `monthLabel(key)` في qasati-standalone_2.html: "<اسم الشهر بالعربي> <السنة>" —
/// بعكس `QuickSalaryMonthLabel` (Phase 6) الذي يحذف السنة عمدًا لغرض مختلف تمامًا
/// (نص ملاحظة راتب سريع، لا عنوان فلتر شهر).
public enum HistoryMonthLabel {
    private static let arabicMonthNames = [
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
        "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ]

    /// `key` بصيغة "YYYY-MM" كما ينتجها `HistoryMonthKey`. يُعيد `key` كما هو إن كان
    /// بصيغة غير متوقَّعة، بدل الانهيار أو افتراض قيمة عشوائية.
    public static func label(forKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              month >= 1, month <= 12
        else {
            return key
        }
        return "\(arabicMonthNames[month - 1]) \(year)"
    }
}
