import Foundation
import XCTest
@testable import QasatiApp
import QasatiSecurityFeature

@MainActor
final class AppLockCoordinatorTests: XCTestCase {

    func test_gracePeriod_isZero() {
        XCTAssertEqual(AppLockCoordinator.gracePeriod, 0)
    }

    func test_handleReturnToActive_nilBackgroundedAt_doesNotLock() {
        let manager = AppLockManager(authenticator: LAContextBiometricAuthenticator(), startLocked: false)

        AppLockCoordinator.handleReturnToActive(backgroundedAt: nil, now: Date(), lockManager: manager)

        XCTAssertEqual(manager.state, .unlocked)
    }

    func test_handleReturnToActive_anyPriorBackgrounding_relocksImmediately() {
        let manager = AppLockManager(authenticator: LAContextBiometricAuthenticator(), startLocked: false)
        let backgroundedAt = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 1_000.001)

        AppLockCoordinator.handleReturnToActive(backgroundedAt: backgroundedAt, now: now, lockManager: manager)

        XCTAssertEqual(manager.state, .locked)
    }

    func test_handleReturnToActive_sameInstant_stillRelocks_zeroGracePeriod() {
        let manager = AppLockManager(authenticator: LAContextBiometricAuthenticator(), startLocked: false)
        let instant = Date(timeIntervalSince1970: 500)

        AppLockCoordinator.handleReturnToActive(backgroundedAt: instant, now: instant, lockManager: manager)

        XCTAssertEqual(manager.state, .locked)
    }

    func test_handleReturnToActive_whenAlreadyLocked_staysLocked() {
        let manager = AppLockManager(authenticator: LAContextBiometricAuthenticator(), startLocked: true)

        AppLockCoordinator.handleReturnToActive(backgroundedAt: Date(), now: Date(), lockManager: manager)

        XCTAssertEqual(manager.state, .locked)
    }
}
