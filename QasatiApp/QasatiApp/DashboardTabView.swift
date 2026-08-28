import SwiftUI
import SwiftData
import QasatiDashboardFeature

/// يحمل DashboardViewModel كـ @State عبر مُهيِّئ مخصَّص (بدل بنائه داخل body مباشرة)
/// لضمان بقاء حالته عبر إعادة تكوين RootView.body — بناؤه ضمن body مباشرة كان سيعيد
/// إنشاءه من الصفر مع كل إعادة رسم لأي حالة أعلى في الشجرة (مثل تغيّر refreshSignal)،
/// فيفقد بياناته المحمَّلة في كل مرة.
@MainActor
struct DashboardTabView: View {
    @State private var viewModel: DashboardViewModel
    let refreshSignal: RefreshSignal

    init(context: ModelContext, refreshSignal: RefreshSignal) {
        _viewModel = State(initialValue: DashboardViewModel(context: context))
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        DashboardView(viewModel: viewModel)
            .onChange(of: refreshSignal.version) { _, _ in viewModel.load() }
    }
}
