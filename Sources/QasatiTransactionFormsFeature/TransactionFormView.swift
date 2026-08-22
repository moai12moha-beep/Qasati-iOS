import SwiftUI
import QasatiDomain

/// نموذج واحد قابل لإعادة الاستخدام لكلا الإيداع والسحب — يقرأ `viewModel.type` فقط
/// ليختار العنوان/الأيقونة/نص الزر، بلا أي منطق مالي أو نداء مباشر لـ
/// TransactionService/TransactionStore/LedgerCalculator من داخل الـ View نفسها.
///
/// `@MainActor` على النوع كاملًا لنفس السبب المكتشَف في إصلاح Phase 4: الخصائص
/// المساعدة الخاصة هنا ليست جزءًا من متطلبات بروتوكول View فلا تكتسب عزل MainActor
/// تلقائيًا، بينما TransactionFormViewModel معزول على @MainActor.
@MainActor
public struct TransactionFormView: View {
    @Bindable var viewModel: TransactionFormViewModel
    @FocusState private var isAmountFieldFocused: Bool

    public init(viewModel: TransactionFormViewModel) {
        self.viewModel = viewModel
    }

    private var title: String {
        viewModel.type == .deposit ? "إضافة مبلغ" : "سحب من القاصة"
    }

    private var icon: String {
        viewModel.type == .deposit ? "📥" : "📤"
    }

    private var submitLabel: String {
        viewModel.type == .deposit ? "إضافة إلى القاصة" : "سحب من القاصة"
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack {
                Text(icon)
                Text(title)
                    .font(.headline)
            }

            amountField
            noteField

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(submitLabel) {
                viewModel.submit()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: viewModel.focusAmountFieldSignal) { _, _ in
            isAmountFieldFocused = true
        }
    }

    private var amountField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("المبلغ")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $viewModel.amountText)
                #if canImport(UIKit)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .focused($isAmountFieldFocused)
        }
    }

    private var noteField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("الملاحظات (اختياري)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $viewModel.noteText)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
        }
    }
}
