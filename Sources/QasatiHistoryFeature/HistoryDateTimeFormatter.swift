import Foundation

/// يطابق `formatDateTime(dateISO)` في qasati-standalone_2.html: "DD/MM/YYYY — HH:MM ص/م"
/// بنظام 12 ساعة وتوقيت الجهاز المحلي. تنسيق عرضي بحت — لا علاقة له بـ `dateISO`
/// المخزَّن نفسه، الذي يبقى دون تغيير.
public enum HistoryDateTimeFormatter {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: date)
        let day = String(format: "%02d", comps.day ?? 0)
        let month = String(format: "%02d", comps.month ?? 0)
        let year = comps.year ?? 0
        let hour24 = comps.hour ?? 0
        let minute = String(format: "%02d", comps.minute ?? 0)
        let ampm = hour24 >= 12 ? "م" : "ص"
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        let hourString = String(format: "%02d", hour12)
        return "\(day)/\(month)/\(year) — \(hourString):\(minute) \(ampm)"
    }
}
