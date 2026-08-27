import SwiftUI
import Accessibility

/// نافذة تعديل عملية موجودة. عمدًا لا تعرض/تُعدّل التاريخ إطلاقًا — فقط نص تنويه ثابت،
/// يطابق edit-hint في qasati-standalone_2.html حرفيًا («التاريخ والوقت الأصليان
/// للعملية سيبقيان دون تغيير.»)، بلا أي تنسيق تاريخ هنا (يتفادى أي اعتماد عكسي على
/// QasatiHistoryFeature، الذي يعتمد أصلًا على هذا الهدف لعرض هذه الشاشة).
@MainActor
public struct EditTransactionView: View {
    @Bindable var viewModel: EditTransactionViewModel
    let onCancel: () -> Void
    let onSaved: () -> Void

    public init(
        viewModel: EditTransactionViewModel,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            Text("✏️ تعديل العملية")
                .font(.headline)

            amountField
            noteField

            Text("التاريخ والوقت الأصليان للعملية سيبقيان دون تغيير.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("إلغاء", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button("حفظ التعديلات") {
                    viewModel.save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
            if didSave {
                onSaved()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard let newValue else { return }
            AccessibilityNotification.Announcement(newValue).post()
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
                .accessibilityLabel("المبلغ")
        }
    }

    private var noteField: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("الملاحظات")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $viewModel.noteText)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("الملاحظات")
        }
    }
}
