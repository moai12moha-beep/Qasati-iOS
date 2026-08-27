import SwiftUI

/// شاشة قفل بحتة تعرض حالة AppLockManager فقط — لا وصول لأي بيانات مالية، ولا
/// استيراد لأي هدف Qasati آخر. لا تُستدعى تلقائيًا عند الإطلاق/الخلفية بعد؛ ذلك
/// تكامل دورة حياة حقيقي مؤجَّل لمرحلة Xcode (Phase 11، القرار 2 و3).
///
/// `@MainActor` على النوع كاملًا لنفس السبب المُكتشَف في إصلاح Phase 4: الخصائص
/// المساعدة الخاصة هنا ليست جزءًا من متطلبات بروتوكول View فلا تكتسب عزل MainActor
/// تلقائيًا، بينما AppLockManager معزول على @MainActor.
@MainActor
public struct AppLockView: View {
    let manager: AppLockManager

    public init(manager: AppLockManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("قاصتي مقفلة")
                .font(.title2.weight(.bold))

            Text(availabilityDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let failureText {
                Text(failureText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await manager.unlock(reason: "افتح قاصتي") }
            } label: {
                Text("فتح القفل")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.state == .authenticating)
        }
        .padding(32)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var iconName: String {
        switch manager.availability {
        case .available(.faceID): return "faceid"
        case .available(.touchID): return "touchid"
        case .available(.none), .unavailable: return "lock.fill"
        }
    }

    private var availabilityDescription: String {
        switch manager.availability {
        case .available(.faceID):
            return "استخدم Face ID لفتح قاصتي"
        case .available(.touchID):
            return "استخدم Touch ID لفتح قاصتي"
        case .available(.none):
            return "استخدم رمز مرور الجهاز لفتح قاصتي"
        case .unavailable(.notSupported):
            return "المصادقة الحيوية غير مدعومة على هذا الجهاز"
        case .unavailable(.noEnrollment):
            return "لم يتم تسجيل أي بصمة/وجه على هذا الجهاز"
        case .unavailable(.lockedOut):
            return "تم قفل المصادقة الحيوية مؤقتًا بسبب محاولات فاشلة متكررة"
        case .unavailable(.other):
            return "تعذّر استخدام المصادقة الحيوية حاليًا"
        }
    }

    private var failureText: String? {
        switch manager.lastFailureReason {
        case nil, .success:
            return nil
        case .failed:
            return "فشلت المصادقة، حاول مرة أخرى"
        case .userCanceled:
            return "تم إلغاء المصادقة"
        case .systemCanceled:
            return "تم إلغاء المصادقة من قبل النظام"
        case .biometryNotAvailable:
            return "المصادقة الحيوية غير متاحة حاليًا"
        case .biometryNotEnrolled:
            return "لم يتم تسجيل أي بصمة/وجه على هذا الجهاز"
        case .passcodeNotSet:
            return "لا يوجد رمز مرور مُعرَّف على هذا الجهاز"
        case .other:
            return "تعذّرت المصادقة لسبب غير معروف"
        }
    }
}
