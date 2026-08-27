import XCTest
import LocalAuthentication
@testable import QasatiSecurityFeature

/// يختبر دالتيّ التعيين النقيتين في LAContextBiometricAuthenticator عبر أخطاء
/// LAError مُصطنَعة — بلا أي حاجة لجهاز حقيقي أو مستشعر فعلي.
final class BiometricErrorMappingTests: XCTestCase {

    private func error(_ code: LAError.Code) -> NSError {
        NSError(domain: LAErrorDomain, code: code.rawValue)
    }

    // MARK: - result(for:)

    func test_result_authenticationFailed_mapsToFailed() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.authenticationFailed)), .failed)
    }

    func test_result_userCancel_mapsToUserCanceled() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.userCancel)), .userCanceled)
    }

    func test_result_systemCancel_mapsToSystemCanceled() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.systemCancel)), .systemCanceled)
    }

    func test_result_appCancel_mapsToSystemCanceled() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.appCancel)), .systemCanceled)
    }

    func test_result_biometryNotAvailable_mapsToBiometryNotAvailable() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.biometryNotAvailable)), .biometryNotAvailable)
    }

    func test_result_biometryLockout_mapsToBiometryNotAvailable() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.biometryLockout)), .biometryNotAvailable)
    }

    func test_result_biometryNotEnrolled_mapsToBiometryNotEnrolled() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.biometryNotEnrolled)), .biometryNotEnrolled)
    }

    func test_result_passcodeNotSet_mapsToPasscodeNotSet() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.passcodeNotSet)), .passcodeNotSet)
    }

    func test_result_invalidContext_mapsToOther() {
        XCTAssertEqual(LAContextBiometricAuthenticator.result(for: error(.invalidContext)), .other)
    }

    // MARK: - unavailableReason(for:)

    func test_unavailableReason_biometryNotAvailable_mapsToNotSupported() {
        XCTAssertEqual(LAContextBiometricAuthenticator.unavailableReason(for: error(.biometryNotAvailable)), .notSupported)
    }

    func test_unavailableReason_biometryNotEnrolled_mapsToNoEnrollment() {
        XCTAssertEqual(LAContextBiometricAuthenticator.unavailableReason(for: error(.biometryNotEnrolled)), .noEnrollment)
    }

    func test_unavailableReason_biometryLockout_mapsToLockedOut() {
        XCTAssertEqual(LAContextBiometricAuthenticator.unavailableReason(for: error(.biometryLockout)), .lockedOut)
    }

    func test_unavailableReason_passcodeNotSet_mapsToOther() {
        XCTAssertEqual(LAContextBiometricAuthenticator.unavailableReason(for: error(.passcodeNotSet)), .other)
    }

    func test_unavailableReason_nilError_mapsToOther() {
        XCTAssertEqual(LAContextBiometricAuthenticator.unavailableReason(for: nil), .other)
    }
}
