import SwiftUI
import QasatiDomain
import QasatiPresentation

/// صف واحد في السجل. عرض بحت لـ `LedgerEntry` جاهز مسبقًا (transaction + balanceAfter) —
/// لا يحسب رصيدًا، لا يستدعي LedgerCalculator/TransactionStore. لا يعتمد على اللون وحده
/// للتمييز بين الإيداع والسحب: أيقونة ونص "إيداع/سحب" مرفقان دائمًا مع اللون.
public struct HistoryRowView: View {
    let entry: LedgerEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    public init(entry: LedgerEntry, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var isDeposit: Bool { entry.transaction.type == .deposit }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                Text(isDeposit ? "🟢" : "🔴")
                Text(isDeposit ? "إيداع" : "سحب")
                    .fontWeight(.bold)
                    .foregroundStyle(isDeposit ? .green : .red)
                Spacer()
                Text("\(isDeposit ? "+" : "-")\(IQDFormatter.formatIQD(entry.transaction.amount))")
                    .fontWeight(.heavy)
                    .foregroundStyle(isDeposit ? .green : .red)
            }

            if !entry.transaction.note.isEmpty {
                Text(entry.transaction.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("📅 \(HistoryDateTimeFormatter.string(from: entry.transaction.dateISO))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("الرصيد بعد العملية: \(IQDFormatter.formatIQD(entry.balanceAfter))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("حذف العملية")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("تعديل العملية")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
