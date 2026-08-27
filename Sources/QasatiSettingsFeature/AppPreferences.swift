import Foundation
import Observation

/// وضع المظهر المُختار — نوع بسيط مستقل عن SwiftUI عمدًا، لإبقاء AppPreferences طبقة
/// حالة/تخزين بحتة بلا اعتماد على إطار عرض معيّن. طبقة العرض (SettingsView) هي من
/// تُترجمه لاحقًا إلى ColorScheme الخاص بـ SwiftUI عند الحاجة (خارج نطاق Phase 10).
public enum AppColorScheme: String, Sendable {
    case light
    case dark
}

/// تفضيلات المستخدم البسيطة (الوضع الليلي/النهاري، إخفاء الرصيد) — مخزَّنة عبر
/// UserDefaults، تمامًا كما استخدم المصدر localStorage لنفس الغرض بالضبط
/// (qasati_theme، qasati_privacy_hidden). لا علاقة لهذا بـ SwiftData/ModelContext
/// إطلاقًا — تفضيلات عرض بحتة، وليست بيانات مالية.
@MainActor
@Observable
public final class AppPreferences {
    private enum Keys {
        static let theme = "qasati_theme"
        static let privacyHidden = "qasati_privacy_hidden"
    }

    private let defaults: UserDefaults

    /// `nil` يعني: لا يوجد تفضيل مستخدم صريح — اتبع مظهر النظام. بمجرد أن يبدّل
    /// المستخدم مرة واحدة، تصبح القيمة صريحة دومًا (فاتح أو داكن) ولا تعود تلقائيًا
    /// إلى "اتباع النظام" — يطابق سلوك المصدر.
    public private(set) var colorScheme: AppColorScheme?
    public private(set) var isBalanceHidden: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        switch defaults.string(forKey: Keys.theme) {
        case AppColorScheme.dark.rawValue: colorScheme = .dark
        case AppColorScheme.light.rawValue: colorScheme = .light
        default: colorScheme = nil
        }

        isBalanceHidden = defaults.bool(forKey: Keys.privacyHidden)
    }

    /// يبدّل بين فاتح/داكن. إن لم يوجد تفضيل صريح بعد (nil)، يُستخدَم `systemAppearance`
    /// (المظهر الفعلي الحالي للنظام، يُحقَن من طبقة العرض عبر SwiftUI's
    /// `@Environment(\.colorScheme)`) كنقطة الانطلاق: أول ضغطة تنتقل دومًا إلى **عكس**
    /// المظهر الفعلي الحالي — فاتح+nil → أول ضغطة تُنتج داكن، وداكن+nil → أول ضغطة
    /// تُنتج فاتح. بمجرد وجود تفضيل صريح، `systemAppearance` يُتجاهَل تمامًا والتبديل
    /// يصبح فاتح↔داكن عاديًا كما كان. لا حالة ثالثة مُخترَعة: الناتج دومًا فاتح أو داكن
    /// فقط، ونفس القاعدة تُطبَّق باستدعاء واحد للدالة، لا حاجة لتفريع سلوك إضافي.
    public func toggleTheme(systemAppearance: AppColorScheme) {
        let base = colorScheme ?? systemAppearance
        colorScheme = (base == .dark) ? .light : .dark
        defaults.set(colorScheme?.rawValue, forKey: Keys.theme)
    }

    public func togglePrivacy() {
        isBalanceHidden.toggle()
        defaults.set(isBalanceHidden, forKey: Keys.privacyHidden)
    }
}
