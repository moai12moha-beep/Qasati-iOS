import Foundation
import QasatiSecurityFeature

/// طبقة تنسيق تطبيق بحتة فوق AppLockManager.shouldRelock (غير مُعدَّلة) وAppLockManager
/// .lock() (غير مُعدَّلة) — لا تُغيّر آلة حالة AppLockManager المُختبَرة بأي شكل.
/// gracePeriod ثابتة عند 0 (Phase 16، القرار 2): أي عودة من الخلفية بعد أي تغييب تُعيد
/// القفل فورًا، طالما القفل مُفعَّل أصلًا (يُحدَّده isAppLockEnabled في RootView).
enum AppLockCoordinator {
    static let gracePeriod: TimeInterval = 0

    @MainActor
    static func handleReturnToActive(
        backgroundedAt: Date?,
        now: Date = Date(),
        lockManager: AppLockManager
    ) {
        guard let backgroundedAt else { return }
        if AppLockManager.shouldRelock(backgroundedAt: backgroundedAt, now: now, gracePeriod: gracePeriod) {
            lockManager.lock()
        }
    }
}
