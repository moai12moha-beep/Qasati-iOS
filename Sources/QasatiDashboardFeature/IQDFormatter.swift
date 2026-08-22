import Foundation

/// تنسيق عرضي بحت للمبالغ بالدينار العراقي — لا يغيّر أي قيمة مخزَّنة أو محسوبة،
/// فقط يحوّل Int (من طبقة Domain) إلى نص للعرض. عمدًا داخل QasatiDashboardFeature
/// وليس QasatiDomain: هذا تنسيق UI، وليس قاعدة عمل.
///
/// يطابق formatNumberOnly/formatIQD في qasati-standalone_2.html: فواصل آلاف بأسلوب
/// en-US ثم لاحقة "د.ع"، ومطابقة أيضًا لمنطق الإشارة الصريحة (+/-) المستخدَم في عرض
/// "ملخص هذا الشهر" هناك.
public enum IQDFormatter {

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// يطابق formatNumberOnly: أرقام مع فواصل الآلاف، بلا لاحقة عملة.
    public static func formatNumberOnly(_ amount: Int) -> String {
        numberFormatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    /// يطابق formatIQD: نفس التنسيق أعلاه + لاحقة " د.ع".
    public static func formatIQD(_ amount: Int) -> String {
        "\(formatNumberOnly(amount)) د.ع"
    }

    /// يطابق منطق عرض "ملخص هذا الشهر" في المصدر: إشارة +/- صريحة أمام القيمة المطلقة
    /// المنسَّقة، وبلا إشارة إن كانت القيمة صفرًا تمامًا.
    public static func formatSignedMonthNet(_ monthNet: Int) -> String {
        let sign = monthNet > 0 ? "+" : (monthNet < 0 ? "-" : "")
        return "\(sign)\(formatIQD(abs(monthNet)))"
    }
}
