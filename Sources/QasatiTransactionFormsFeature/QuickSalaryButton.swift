import SwiftUI

/// زر "راتب سريع". لا يملك حالته الخاصة، لا ينشئ ViewModel جديد، لا ينشئ عملية، ولا
/// يلمس TransactionService/TransactionStore أبدًا — يستدعي فقط applyQuickSalaryPrefill
/// على نسخة TransactionFormViewModel **الموجودة مسبقًا** والمرتبطة فعليًا بنموذج الإيداع
/// المعروض؛ لا ينشئ أي نسخة جديدة من الـ ViewModel بنفسه.
@MainActor
public struct QuickSalaryButton: View {
    let viewModel: TransactionFormViewModel

    public init(viewModel: TransactionFormViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Button {
            viewModel.applyQuickSalaryPrefill(monthLabel: QuickSalaryMonthLabel.current())
        } label: {
            Text("⚡ إضافة راتب سريع")
        }
    }
}
