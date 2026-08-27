import SwiftUI

/// مفتاح بيئة SwiftUI يعكس تفضيل "إخفاء الرصيد" — قيمة Bool بسيطة بلا أي اعتماد على
/// QasatiSettingsFeature أو أي منطق تخزين تفضيلات. أي شاشة تريد احترام هذا التفضيل
/// (مثل QasatiDashboardFeature) تقرأه من البيئة فقط؛ من يملك القيمة الفعلية
/// (AppPreferences في Phase 10) هو من يحقنها لاحقًا عبر .environment(\.isBalanceHidden, ...)
/// عند تجميع الشاشات معًا (مرحلة تكامل لاحقة).
private struct BalanceVisibilityKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    public var isBalanceHidden: Bool {
        get { self[BalanceVisibilityKey.self] }
        set { self[BalanceVisibilityKey.self] = newValue }
    }
}
