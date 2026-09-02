import SwiftUI
import SwiftData
import QasatiDomain
import QasatiTransactionFormsFeature

/// يحمل TransactionFormViewModel منفصل لكل من الإيداع والسحب، وكلاهما @State (نفس سبب
/// DashboardTabView). زر "راتب سريع" يُستخدَم على نفس نسخة viewModel الإيداع الموجودة
/// مسبقًا فقط — لا ينشئ نسخة جديدة، ولا يُنشئ عملية بنفسه (يطابق سلوك QuickSalaryButton
/// المُختبَر أصلًا بلا أي تعديل).
@MainActor
struct AddTransactionTabView: View {
    @State private var depositViewModel: TransactionFormViewModel
    @State private var withdrawViewModel: TransactionFormViewModel
    @State private var selectedType: TransactionType = .deposit
    let refreshSignal: RefreshSignal

    init(context: ModelContext, refreshSignal: RefreshSignal) {
        _depositViewModel = State(initialValue: TransactionFormViewModel(type: .deposit, context: context))
        _withdrawViewModel = State(initialValue: TransactionFormViewModel(type: .withdraw, context: context))
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("النوع", selection: $selectedType) {
                Text("إيداع").tag(TransactionType.deposit)
                Text("سحب").tag(TransactionType.withdraw)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedType == .deposit {
                QuickSalaryButton(viewModel: depositViewModel)
                TransactionFormView(viewModel: depositViewModel)
                    .onChange(of: depositViewModel.didSaveSuccessfully) { _, saved in
                        if saved { refreshSignal.bump() }
                    }
            } else {
                TransactionFormView(viewModel: withdrawViewModel)
                    .onChange(of: withdrawViewModel.didSaveSuccessfully) { _, saved in
                        if saved { refreshSignal.bump() }
                    }
            }

            Spacer()
        }
        .padding(.top)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
