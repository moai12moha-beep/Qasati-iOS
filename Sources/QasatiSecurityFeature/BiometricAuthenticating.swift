import Foundation

/// نوع القياس الحيوي المتاح على الجهاز — تصنيف عرضي فقط، لا علاقة له بأي بيانات
/// حيوية فعلية. يُستخدَم فقط لاختيار النص/الأيقونة المناسبة في الواجهة.
public enum BiometricKind: Equatable {
    case faceID
    case touchID
    case none
}

/// سبب عدم توفر المصادقة الحيوية/مصادقة مالك الجهاز حاليًا.
public enum BiometricUnavailableReason: Equatable {
    case notSupported
    case noEnrollment
    case lockedOut
    case other
}

public enum BiometricAvailability: Equatable {
    case available(BiometricKind)
    case unavailable(BiometricUnavailableReason)
}

/// نتيجة محاولة مصادقة واحدة. لا يحمل أي منها بيانات حيوية أو سرّية إطلاقًا — فقط
/// تصنيف للنتيجة، تمامًا كما يُعيد LocalAuthentication نفسه (نجاح/فشل/سبب)، لا أكثر.
public enum BiometricAuthenticationResult: Equatable {
    case success
    case failed
    case userCanceled
    case systemCanceled
    case biometryNotAvailable
    case biometryNotEnrolled
    case passcodeNotSet
    case other
}

/// تجريد للمصادقة — يسمح باختبار كل منطق القفل/الفتح (AppLockManager) بلا حاجة
/// لجهاز حقيقي أو مستشعر فعلي، عبر حقن تنفيذ زائف بدل LAContextBiometricAuthenticator
/// الحقيقي في الاختبارات. مُستخدَم فقط من داخل AppLockManager المعزول على @MainActor،
/// فلا حاجة لتقييد Sendable هنا.
public protocol BiometricAuthenticating {
    func availability() -> BiometricAvailability
    func authenticate(reason: String) async -> BiometricAuthenticationResult
}
