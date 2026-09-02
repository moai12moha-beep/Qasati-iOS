import SwiftUI
import SwiftData
import QasatiHistoryFeature

/// يستخدم إشارة النجاح المباشرة الجديدة HistoryView.onMutationSucceeded (المُضافة في
/// إصلاح refresh-signal-fix) — تُستدعى فعليًا فقط بعد تعديل أو حذف ناجح حقيقي (مبنية
/// داخل HistoryView على didDeleteSucceed لـ HistoryViewModel)، بلا أي استنتاج من
/// allEntries أو أي حالة أخرى.
@MainActor
struct HistoryTabView: View {
    @State private var viewModel: HistoryViewModel
    let context: ModelContext
    let refreshSignal: RefreshSignal

    init(context: ModelContext, refreshSignal: RefreshSignal) {
        _viewModel = State(initialValue: HistoryViewModel(context: context))
        self.context = context
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        HistoryView(
            viewModel: viewModel,
            context: context,
            onMutationSucceeded: { refreshSignal.bump() }
        )
        .onChange(of: refreshSignal.version) { _, _ in viewModel.load() }
    }
}
