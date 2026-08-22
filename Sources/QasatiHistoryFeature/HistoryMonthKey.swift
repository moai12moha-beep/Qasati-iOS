import Foundation

/// مفتاح تجميع شهري نصي بصيغة "YYYY-MM"، مستقل تمامًا عن `LedgerCalculator` عمدًا:
/// ذلك النوع يملك مفتاحًا شهريًا مشابهًا داخليًا (private) لحساب `monthNet`، وهو رقم
/// مالي، بينما هذا مفتاح تجميع/فلترة عرضي بحت للسجل، بلا أي حساب مالي على الإطلاق —
/// فصلهما مقصود، وليس ازدواجية لمنطق مالي.
public enum HistoryMonthKey {
    /// `calendar` قابل للحقن عمدًا لجعل الاختبار حتميًا، بنفس أسلوب
    /// `LedgerCalculator.summary(now:calendar:)` في Phase 1. الافتراضي (`Calendar.current`)
    /// يطابق فلسفة توقيت الجهاز المحلي المُتبَعة في كل مكان آخر بالمشروع.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}
