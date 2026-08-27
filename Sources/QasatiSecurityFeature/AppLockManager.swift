import Foundation
import Observation

public enum AppLockState: Equatable {
    case locked
    case unlocked
    case authenticating
}

/// آلة حالة القفل/الفتح فقط — لا وصول لأي بيانات مالية إطلاقًا (لا استيراد لـ
/// QasatiDomain/QasatiPersistence/QasatiTransactionService)، ولا اعتماد على
/// AppPreferences (Phase 10): حالة القفل جلسة مؤقتة، والتفضيلات إعدادات دائمة —
/// مفهومان منفصلان عمدًا.
///
/// **مهم**: لا شيء هنا يربط هذه الآلة بلحظة إطلاق التطبيق الفعلية أو العودة من
/// الخلفية — ذلك تكامل دورة حياة حقيقي مؤجَّل لمرحلة Xcode. هذا الملف يوفّر فقط
/// المنطق القابل للاختبار الحتمي؛ لا ادّعاء بأن القفل عند الإطلاق/الخلفية "يعمل".
@MainActor
@Observable
public final class AppLockManager {
    public private(set) var state: AppLockState
    public private(set) var lastFailureReason: BiometricAuthenticationResult?

    private let authenticator: BiometricAuthenticating

    /// `startLocked` قابل للحقن عمدًا (بدل قراءة حالة تطبيق حقيقية) لجعل الحالة
    /// الابتدائية حتمية وقابلة للاختبار.
    public init(authenticator: BiometricAuthenticating, startLocked: Bool) {
        self.authenticator = authenticator
        self.state = startLocked ? .locked : .unlocked
    }

    public var availability: BiometricAvailability {
        authenticator.availability()
    }

    /// يطلب مصادقة، ويُحدّث الحالة وفقًا للنتيجة. النجاح فقط يفتح القفل؛ أي نتيجة
    /// أخرى (فشل/إلغاء المستخدم/إلغاء النظام/عدم توفر/عدم تسجيل/بلا رمز مرور جهاز)
    /// تُبقي الحالة locked مع حفظ السبب للعرض والسماح بإعادة المحاولة — لا حالة
    /// "فتح جزئي" على الإطلاق، ولا كشف لأي بيانات قبل نجاح صريح.
    public func unlock(reason: String) async {
        guard state != .unlocked else { return }
        state = .authenticating
        let result = await authenticator.authenticate(reason: reason)
        switch result {
        case .success:
            lastFailureReason = nil
            state = .unlocked
        default:
            lastFailureReason = result
            state = .locked
        }
    }

    /// يُعيد الحالة إلى locked. استدعاؤها الفعلي عند العودة من الخلفية مؤجَّل لمرحلة
    /// تكامل دورة حياة Xcode — هذه الدالة فقط تُطبِّق التغيير عند استدعائها يدويًا.
    public func lock() {
        state = .locked
        lastFailureReason = nil
    }

    /// دالة قرار نقية بالكامل (بلا ساعة حقيقية، بلا مؤقّت فعلي) لتحديد ما إذا انتهت
    /// فترة سماح افتراضية. لا تُحدَّد أي مدة نهائية للمنتج هنا — المستدعي (مرحلة لاحقة)
    /// هو من يقرّر gracePeriod الفعلية؛ هذه فقط منطق المقارنة الحتمي القابل للاختبار.
    public static func shouldRelock(backgroundedAt: Date, now: Date, gracePeriod: TimeInterval) -> Bool {
        now.timeIntervalSince(backgroundedAt) >= gracePeriod
    }
}
