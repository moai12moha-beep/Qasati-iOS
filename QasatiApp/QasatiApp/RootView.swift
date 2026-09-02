import SwiftUI
import QasatiPersistence
import QasatiPresentation
import QasatiSettingsFeature
import QasatiSecurityFeature

enum AppTab: Hashable {
    case dashboard, addTransaction, history, settings
}

/// يطابق دلالة Phase 10 المُعتمَدة تمامًا: `nil` (لا تفضيل صريح بعد) → `nil` هنا أيضًا،
/// وهو ما يعنيه SwiftUI's `.preferredColorScheme(nil)` أصلًا: اتباع مظهر النظام تلقائيًا،
/// بلا أي منطق إضافي.
func mappedColorScheme(for preference: AppColorScheme?) -> ColorScheme? {
    switch preference {
    case .light: return .light
    case .dark: return .dark
    case nil: return nil
    }
}

/// جذر التطبيق: يملك التفضيلات وحالة القفل الأمني وإشارة إعادة التحميل، ويحقن كل ما
/// تحتاجه الشاشات الأربع عبر البيئة/الحقن المباشر، بلا أي منطق مالي هنا إطلاقًا — كل
/// شاشة تستدعي طبقاتها الموجودة مسبقًا (QasatiDashboardFeature/...) كما هي دون تعديل.
@MainActor
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var preferences = AppPreferences()
    @State private var lockManager = AppLockManager(
        authenticator: LAContextBiometricAuthenticator(),
        startLocked: false // Phase 16، القرار 1: القفل معطَّل افتراضيًا
    )
    @State private var refreshSignal = RefreshSignal()
    @State private var selectedTab: AppTab = .dashboard
    @State private var backgroundedAt: Date?

    /// علم داخلي بحت، بلا أي واجهة مستخدم تُعرِّضه — يُبقي كامل آلية القفل/scenePhase
    /// خاملة تمامًا (يطابق "القفل معطَّل افتراضيًا") دون حذف التصميم المُختبَر، وقابلة
    /// للتفعيل لاحقًا (يدويًا هنا، أو عبر تفضيل إعدادات حقيقي في مرحلة لاحقة معتمَدة)
    /// بلا أي إعادة هيكلة للجذر.
    @State private var isAppLockEnabled = false

    var body: some View {
        Group {
            if isAppLockEnabled, lockManager.state != .unlocked {
                AppLockView(manager: lockManager)
            } else {
                TabView(selection: $selectedTab) {
                    DashboardTabView(context: modelContext, refreshSignal: refreshSignal)
                        .tabItem {
                            Label("الرئيسية", systemImage: "house.fill")
                                .accessibilityIdentifier("tab.dashboard")
                        }
                        .tag(AppTab.dashboard)

                    AddTransactionTabView(context: modelContext, refreshSignal: refreshSignal)
                        .tabItem {
                            Label("إضافة", systemImage: "plus.circle.fill")
                                .accessibilityIdentifier("tab.addTransaction")
                        }
                        .tag(AppTab.addTransaction)

                    HistoryTabView(context: modelContext, refreshSignal: refreshSignal)
                        .tabItem {
                            Label("السجل", systemImage: "clock.fill")
                                .accessibilityIdentifier("tab.history")
                        }
                        .tag(AppTab.history)

                    SettingsTabView(context: modelContext, preferences: preferences, refreshSignal: refreshSignal)
                        .tabItem {
                            Label("الإعدادات", systemImage: "gearshape.fill")
                                .accessibilityIdentifier("tab.settings")
                        }
                        .tag(AppTab.settings)
                }
            }
        }
        .environment(\.isBalanceHidden, preferences.isBalanceHidden)
        .preferredColorScheme(mappedColorScheme(for: preferences.colorScheme))
        .onChange(of: scenePhase) { _, newPhase in
            guard isAppLockEnabled else { return }
            switch newPhase {
            case .background:
                backgroundedAt = Date()
            case .active:
                AppLockCoordinator.handleReturnToActive(backgroundedAt: backgroundedAt, lockManager: lockManager)
            default:
                break
            }
        }
    }
}
