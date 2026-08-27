import Foundation
import LocalAuthentication

/// التنفيذ الحقيقي الوحيد لـ BiometricAuthenticating، عبر LocalAuthentication من Apple.
/// لا يُخزِّن أي بيانات حيوية أو سرّية على الإطلاق — LAContext تُطابق البصمة/الوجه
/// داخل Secure Enclave فقط، وهذا الكود لا يرى ولا يستقبل سوى النتيجة (نجاح/فشل/سبب).
/// لا نظام PIN/كلمة مرور خاص بالتطبيق يُنفَّذ هنا أو في أي مكان آخر.
///
/// السياسة المستخدَمة: `.deviceOwnerAuthentication` — Face ID/Touch ID أولًا، مع
/// السماح بالرجوع لرمز مرور الجهاز (device passcode) تلقائيًا عند تعذّر/عدم توفر
/// المقياس الحيوي، بموافقة صريحة (Phase 11، القرار 1). السياسة مُحصورة هنا فقط.
///
/// تنبيه مهم غير قابل للتحقق من هذه البيئة: تفعيل Face ID فعليًا على جهاز حقيقي
/// يتطلب مفتاح `NSFaceIDUsageDescription` في Info.plist لتطبيق Xcode الفعلي — وهو
/// غير موجود بعد (لا مشروع Xcode في هذا المستودع). هذا الملف يُصرَّف ويُختبَر منطقيًا
/// عبر BiometricErrorMappingTests فقط؛ لا مصادقة حقيقية جرت أو يمكن أن تجري هنا.
public final class LAContextBiometricAuthenticator: BiometricAuthenticating {
    public init() {}

    public func availability() -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable(Self.unavailableReason(for: error))
        }

        switch context.biometryType {
        case .faceID: return .available(.faceID)
        case .touchID: return .available(.touchID)
        default: return .available(.none)
        }
    }

    public func authenticate(reason: String) async -> BiometricAuthenticationResult {
        let context = LAContext()
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: .success)
                } else if let nsError = error as NSError? {
                    continuation.resume(returning: Self.result(for: nsError))
                } else {
                    continuation.resume(returning: .failed)
                }
            }
        }
    }

    /// دالة تعيين نقية (pure) — قابلة للاختبار مباشرة بأخطاء LAError مُصطنَعة، بلا أي
    /// حاجة لجهاز حقيقي أو استدعاء LAContext فعلي.
    static func unavailableReason(for error: NSError?) -> BiometricUnavailableReason {
        guard let code = error.flatMap({ LAError.Code(rawValue: $0.code) }) else { return .other }
        switch code {
        case .biometryNotAvailable: return .notSupported
        case .biometryNotEnrolled: return .noEnrollment
        case .biometryLockout: return .lockedOut
        default: return .other
        }
    }

    /// دالة تعيين نقية أخرى، لنفس السبب أعلاه.
    static func result(for error: NSError) -> BiometricAuthenticationResult {
        guard let code = LAError.Code(rawValue: error.code) else { return .other }
        switch code {
        case .authenticationFailed: return .failed
        case .userCancel: return .userCanceled
        case .systemCancel, .appCancel: return .systemCanceled
        case .biometryNotAvailable, .biometryLockout: return .biometryNotAvailable
        case .biometryNotEnrolled: return .biometryNotEnrolled
        case .passcodeNotSet: return .passcodeNotSet
        default: return .other
        }
    }
}
