import XCTest
@testable import QasatiSecurityFeature

// Swift 6 forward-compat: XCTestCase itself is nonisolated, so the class is left
// nonisolated and each test method that touches the @MainActor-isolated
// AppLockManager is annotated @MainActor individually instead. This avoids the
// "different actor isolation from nonisolated superclass" warning without
// changing production actor isolation.
final class AppLockManagerTests: XCTestCase {

    // MARK: - Initial state

    @MainActor
    func test_init_startLockedTrue_stateIsLocked() {
        let fake = FakeBiometricAuthenticator()
        let manager = AppLockManager(authenticator: fake, startLocked: true)

        XCTAssertEqual(manager.state, .locked)
        XCTAssertNil(manager.lastFailureReason)
    }

    @MainActor
    func test_init_startLockedFalse_stateIsUnlocked() {
        let fake = FakeBiometricAuthenticator()
        let manager = AppLockManager(authenticator: fake, startLocked: false)

        XCTAssertEqual(manager.state, .unlocked)
    }

    // MARK: - unlock: success

    @MainActor
    func test_unlock_success_transitionsToUnlocked() async {
        let fake = FakeBiometricAuthenticator()
        fake.stubbedResult = .success
        let manager = AppLockManager(authenticator: fake, startLocked: true)

        await manager.unlock(reason: "افتح قاصتي")

        XCTAssertEqual(manager.state, .unlocked)
        XCTAssertNil(manager.lastFailureReason)
        XCTAssertEqual(fake.authenticateCallCount, 1)
        XCTAssertEqual(fake.lastReason, "افتح قاصتي")
    }

    // MARK: - unlock: every non-success result stays locked with the reason stored

    @MainActor
    func test_unlock_failed_staysLockedWithReason() async {
        await assertRemainsLocked(with: .failed)
    }

    @MainActor
    func test_unlock_userCanceled_staysLockedWithReason() async {
        await assertRemainsLocked(with: .userCanceled)
    }

    @MainActor
    func test_unlock_systemCanceled_staysLockedWithReason() async {
        await assertRemainsLocked(with: .systemCanceled)
    }

    @MainActor
    func test_unlock_biometryNotAvailable_staysLockedWithReason() async {
        await assertRemainsLocked(with: .biometryNotAvailable)
    }

    @MainActor
    func test_unlock_biometryNotEnrolled_staysLockedWithReason() async {
        await assertRemainsLocked(with: .biometryNotEnrolled)
    }

    @MainActor
    func test_unlock_passcodeNotSet_staysLockedWithReason() async {
        await assertRemainsLocked(with: .passcodeNotSet)
    }

    @MainActor
    func test_unlock_other_staysLockedWithReason() async {
        await assertRemainsLocked(with: .other)
    }

    @MainActor
    private func assertRemainsLocked(
        with result: BiometricAuthenticationResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let fake = FakeBiometricAuthenticator()
        fake.stubbedResult = result
        let manager = AppLockManager(authenticator: fake, startLocked: true)

        await manager.unlock(reason: "افتح قاصتي")

        XCTAssertEqual(manager.state, .locked, file: file, line: line)
        XCTAssertEqual(manager.lastFailureReason, result, file: file, line: line)
    }

    // MARK: - No re-authentication once unlocked

    @MainActor
    func test_unlock_whenAlreadyUnlocked_doesNotCallAuthenticatorAgain() async {
        let fake = FakeBiometricAuthenticator()
        fake.stubbedResult = .success
        let manager = AppLockManager(authenticator: fake, startLocked: false)

        await manager.unlock(reason: "افتح قاصتي")

        XCTAssertEqual(fake.authenticateCallCount, 0)
        XCTAssertEqual(manager.state, .unlocked)
    }

    // MARK: - lock()

    @MainActor
    func test_lock_resetsStateAndClearsFailureReason() async {
        let fake = FakeBiometricAuthenticator()
        fake.stubbedResult = .failed
        let manager = AppLockManager(authenticator: fake, startLocked: true)
        await manager.unlock(reason: "افتح قاصتي")
        XCTAssertNotNil(manager.lastFailureReason)

        manager.lock()

        XCTAssertEqual(manager.state, .locked)
        XCTAssertNil(manager.lastFailureReason)
    }

    @MainActor
    func test_lock_whenUnlocked_relocksImmediately() {
        let fake = FakeBiometricAuthenticator()
        let manager = AppLockManager(authenticator: fake, startLocked: false)

        manager.lock()

        XCTAssertEqual(manager.state, .locked)
    }

    // MARK: - availability forwarding

    @MainActor
    func test_availability_forwardsAuthenticatorAvailability() {
        let fake = FakeBiometricAuthenticator()
        fake.stubbedAvailability = .unavailable(.noEnrollment)
        let manager = AppLockManager(authenticator: fake, startLocked: true)

        XCTAssertEqual(manager.availability, .unavailable(.noEnrollment))
    }

    // MARK: - shouldRelock: pure grace-period decision function

    @MainActor
    func test_shouldRelock_beforeGracePeriodElapsed_returnsFalse() {
        let backgroundedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1029)

        XCTAssertFalse(AppLockManager.shouldRelock(backgroundedAt: backgroundedAt, now: now, gracePeriod: 30))
    }

    @MainActor
    func test_shouldRelock_exactlyAtGracePeriod_returnsTrue() {
        let backgroundedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1030)

        XCTAssertTrue(AppLockManager.shouldRelock(backgroundedAt: backgroundedAt, now: now, gracePeriod: 30))
    }

    @MainActor
    func test_shouldRelock_afterGracePeriodElapsed_returnsTrue() {
        let backgroundedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1500)

        XCTAssertTrue(AppLockManager.shouldRelock(backgroundedAt: backgroundedAt, now: now, gracePeriod: 30))
    }

    @MainActor
    func test_shouldRelock_zeroGracePeriod_alwaysTrueForAnyElapsedTime() {
        let backgroundedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1000)

        XCTAssertTrue(AppLockManager.shouldRelock(backgroundedAt: backgroundedAt, now: now, gracePeriod: 0))
    }
}
