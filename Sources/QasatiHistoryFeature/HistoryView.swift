import SwiftUI
import SwiftData
import QasatiDomain
import QasatiTransactionFormsFeature

/// شاشة السجل: بحث + فلاتر نوع + فلتر شهر + قائمة + حالة فارغة/لا نتائج. عرض بحت
/// لـ HistoryViewModel — لا حساب مالي، لا استدعاء مباشر لـ TransactionStore/LedgerCalculator.
///
/// `@MainActor` على النوع كاملًا لنفس السبب المكتشَف في إصلاح Phase 4: الخصائص المساعدة
/// الخاصة هنا (content/filterChip وغيرها) ليست جزءًا من متطلبات بروتوكول View فلا تكتسب
/// عزل MainActor تلقائيًا، بينما HistoryViewModel معزول على @MainActor.
@MainActor
public struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    let context: ModelContext

    /// نفس السياق (ModelContext) المُمرَّر لبناء viewModel — مطلوب هنا فقط لإنشاء
    /// EditTransactionViewModel عند فتح نافذة التعديل. HistoryViewModel.context يبقى
    /// خاصًا كما هو (لا كسر لتغليفه)؛ هذا سياق مستقل يُمرَّر من نفس المستدعي.
    public init(viewModel: HistoryViewModel, context: ModelContext) {
        self.viewModel = viewModel
        self.context = context
    }

    @State private var editingEntry: LedgerEntry?
    @State private var pendingDeleteEntry: LedgerEntry?

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
        .sheet(
            isPresented: Binding(
                get: { editingEntry != nil },
                set: { isPresented in if !isPresented { editingEntry = nil } }
            )
        ) {
            if let entry = editingEntry {
                EditTransactionView(
                    viewModel: EditTransactionViewModel(transaction: entry.transaction, context: context),
                    onCancel: { editingEntry = nil },
                    onSaved: {
                        editingEntry = nil
                        viewModel.load()
                    }
                )
            }
        }
        .confirmationDialog(
            "هل أنت متأكد من حذف هذه العملية؟",
            isPresented: Binding(
                get: { pendingDeleteEntry != nil },
                set: { isPresented in if !isPresented { pendingDeleteEntry = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("حذف العملية", role: .destructive) {
                if let id = pendingDeleteEntry?.transaction.id {
                    viewModel.delete(id: id)
                }
                pendingDeleteEntry = nil
            }
            Button("إلغاء", role: .cancel) {
                pendingDeleteEntry = nil
            }
        }
        .alert(
            "خطأ",
            isPresented: Binding(
                get: { viewModel.deleteErrorMessage != nil },
                set: { isPresented in if !isPresented { viewModel.clearDeleteError() } }
            )
        ) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(viewModel.deleteErrorMessage ?? "")
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
                .accessibilityLabel("بحث في الملاحظات")

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
                        HistoryRowView(
                            entry: entry,
                            onEdit: { editingEntry = entry },
                            onDelete: { pendingDeleteEntry = entry }
                        )
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("🔐")
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text("القاصة فارغة").font(.headline)
            Text("ابدأ بإضافة راتبك أو أول مبلغ إلى القاصة.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Text("🔍")
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text("لا توجد نتائج").font(.headline)
            Text("جرّب كلمة بحث أو فلترة مختلفة.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func filterChip(_ filter: HistoryTypeFilter, label: String) -> some View {
        let isSelected = viewModel.typeFilter == filter
        return Button(label) {
            viewModel.typeFilter = filter
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Color.accentColor : Color.secondary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
