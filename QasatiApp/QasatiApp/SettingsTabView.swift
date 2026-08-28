import SwiftUI
import SwiftData
import QasatiSettingsFeature

/// preferences تصل مُشارَكة من RootView (نفس النسخة التي يقرأها الجذر لحقن البيئة/المظهر)
/// — لذا هي `let` عادية هنا، وليست @State (لم تُنشَأ في هذا المستوى). يستخدم إشارة
/// النجاح المباشرة الجديدة SettingsViewModel.didMutateSucceed (المُضافة في إصلاح
/// refresh-signal-fix) — true فقط بعد استيراد أو مسح ناجح حقيقي، ولا تُضبَط أبدًا من
/// exportFile()، بلا أي استنتاج من statusMessage أو isError.
@MainActor
struct SettingsTabView: View {
    let preferences: AppPreferences
    @State private var viewModel: SettingsViewModel
    let refreshSignal: RefreshSignal

    init(context: ModelContext, preferences: AppPreferences, refreshSignal: RefreshSignal) {
        self.preferences = preferences
        _viewModel = State(initialValue: SettingsViewModel(context: context))
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        SettingsView(preferences: preferences, viewModel: viewModel)
            .onChange(of: viewModel.didMutateSucceed) { _, succeeded in
                if succeeded { refreshSignal.bump() }
            }
    }
}
