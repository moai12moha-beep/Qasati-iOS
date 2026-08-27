import Foundation
@testable import QasatiSecurityFeature

/// نظير اختباري بحت — لا يلمس LocalAuthentication أو أي مستشعر حقيقي إطلاقًا.
/// يسمح باختبار AppLockManager حتميًا لكل مسار (نجاح/فشل/إلغاء/عدم توفر/...).
final class FakeBiometricAuthenticator: BiometricAuthenticating {
    var stubbedAvailability: BiometricAvailability = .available(.faceID)
    var stubbedResult: BiometricAuthenticationResult = .success

    private(set) var authenticateCallCount = 0
    private(set) var lastReason: String?

    func availability() -> BiometricAvailability {
        stubbedAvailability
    }

    func authenticate(reason: String) async -> BiometricAuthenticationResult {
        authenticateCallCount += 1
        lastReason = reason
        return stubbedResult
    }
}
