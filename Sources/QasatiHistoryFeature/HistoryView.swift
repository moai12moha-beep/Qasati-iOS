import SwiftUI
import QasatiDomain

/// شاشة السجل: بحث + فلاتر نوع + فلتر شهر + قائمة + حالة فارغة/لا نتائج. عرض بحت
/// لـ HistoryViewModel — لا حساب مالي، لا استدعاء مباشر لـ TransactionStore/LedgerCalculator.
///
/// `@MainActor` على النوع كاملًا لنفس السبب المكتشَف في إصلاح Phase 4: الخصائص المساعدة
/// الخاصة هنا (content/filterChip وغيرها) ليست جزءًا من متطلبات بروتوكول View فلا تكتسب
/// عزل MainActor تلقائيًا، بينما HistoryViewModel معزول على @MainActor.
@MainActor
public struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel

    public init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            content
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            viewModel.load()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text("📒 سجل العمليات")
                    .font(.headline)
                Spacer()
            }

            TextField("🔍 بحث في الملاحظات...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)

            Picker("الشهر", selection: $viewModel.selectedMonthKey) {
                Text("كل الأشهر").tag("all")
                ForEach(viewModel.availableMonthKeys, id: \.self) { key in
                    Text(HistoryMonthLabel.label(forKey: key)).tag(key)
                }
            }
            .pickerStyle(.menu)

            HStack {
                filterChip(.all, label: "الكل")
                filterChip(.deposit, label: "الإيداعات")
                filterChip(.withdraw, label: "السحوبات")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isEmpty {
            emptyStateView
        } else if viewModel.hasNoResults {
            noResultsView
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEntries, id: \.transaction.id) { entry in
                        HistoryRowView(entry: entry)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("🔐").font(.system(size: 40))
            Text("القاصة فارغة").font(.headline)
            Text("ابدأ بإضافة راتبك أو أول مبلغ إلى القاصة.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .multilineTextAlignment(.center)
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Text("🔍").font(.system(size: 40))
            Text("لا توجد نتائج").font(.headline)
            Text("جرّب كلمة بحث أو فلترة مختلفة.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .multilineTextAlignment(.center)
    }

    private func filterChip(_ filter: HistoryTypeFilter, label: String) -> some View {
        Button(label) {
            viewModel.typeFilter = filter
        }
        .buttonStyle(.bordered)
        .tint(viewModel.typeFilter == filter ? Color.accentColor : Color.secondary)
    }
}
