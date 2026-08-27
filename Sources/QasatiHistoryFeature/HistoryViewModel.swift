import Foundation
import Observation
import SwiftData
import QasatiDomain
import QasatiPersistence
import QasatiTransactionService

/// يحمّل كل العمليات ويحوّلها إلى `[LedgerEntry]` عبر `LedgerCalculator.recompute` (غير
/// مُعدَّل) — `balanceAfter` لكل صف يأتي من هناك مباشرة، ولا يُعاد حسابه هنا إطلاقًا.
/// كل تحويل بحث/فلترة/ترتيب يعيش هنا (طبقة قابلة للاختبار)، وليس داخل الـ View.
@MainActor
@Observable
public final class HistoryViewModel {
    public private(set) var allEntries: [LedgerEntry] = []

    public var searchText: String = ""
    public var typeFilter: HistoryTypeFilter = .all
    public var selectedMonthKey: String = "all"

    /// رسالة خطأ الحذف الوحيدة (مثلًا: رفض OQ-1 لأن الحذف سيُنتج رصيدًا سالبًا).
    /// لا يوجد "حالة نجاح" منفصلة للحذف — النجاح يُلاحَظ ببساطة عبر تحديث allEntries
    /// بعد load().
    public private(set) var deleteErrorMessage: String?

    /// خطأ الجلب الفعلي من TransactionStore.fetchAll، إن وُجد — يماثل
    /// DashboardViewModel.loadError (Phase 15): كلاهما يستدعي fetchAll نفسها، فكلاهما
    /// يجب أن يعالج فشلها بنفس الأسلوب (التقاط الخطأ الحقيقي)، بدل تحويله بصمت إلى
    /// قائمة فارغة كما كان الحال هنا سابقًا. لا تغيير في سلوك النجاح: allEntries تُحدَّث
    /// تمامًا كما كانت، ولا تُستخدَم هذه الخاصية بعد من أي View حاليًا.
    public private(set) var loadError: Error?

    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// يجلب كل العمليات ويعيد بناء الترتيب/الرصيد من الصفر — يطابق فلسفة "أعد الحساب
    /// دومًا من سجل العمليات" المُطبَّقة في LedgerCalculator نفسه.
    public func load() {
        do {
            let transactions = try TransactionStore.fetchAll(from: context)
            allEntries = LedgerCalculator.recompute(transactions).ordered
            loadError = nil
        } catch {
            loadError = error
        }
    }

    /// مفاتيح الأشهر الموجودة فعليًا في البيانات، الأحدث أولًا — تُستخدَم لتعبئة قائمة
    /// اختيار الشهر، بلا أي اعتماد على "اليوم الحالي".
    public var availableMonthKeys: [String] {
        let keys = Set(allEntries.map { HistoryMonthKey.key(for: $0.transaction.dateISO, calendar: calendar) })
        return keys.sorted(by: >)
    }

    /// نفس تسلسل الفلترة في المصدر: عكس الترتيب الزمني (الأحدث أولًا)، ثم النوع، ثم
    /// الشهر، ثم البحث — وكلها تُطبَّق معًا بمنطق AND.
    public var filteredEntries: [LedgerEntry] {
        var list = Array(allEntries.reversed())

        if let type = typeFilter.transactionType {
            list = list.filter { $0.transaction.type == type }
        }

        if selectedMonthKey != "all" {
            list = list.filter {
                HistoryMonthKey.key(for: $0.transaction.dateISO, calendar: calendar) == selectedMonthKey
            }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let query = trimmedSearch.lowercased()
            list = list.filter { $0.transaction.note.lowercased().contains(query) }
        }

        return list
    }

    /// لا توجد عمليات إطلاقًا — يطابق شرط `transactions.length === 0` في المصدر.
    public var isEmpty: Bool {
        allEntries.isEmpty
    }

    /// توجد عمليات، لكن الفلاتر/البحث الحالية لا تُطابق أيًا منها — يطابق شرط
    /// `filtered.length === 0` (بعد استبعاد الحالة الفارغة تمامًا) في المصدر.
    public var hasNoResults: Bool {
        !allEntries.isEmpty && filteredEntries.isEmpty
    }

    /// يحذف عملية بمعرّفها عبر TransactionService.delete (غير مُعدَّل) — الذي يُفوّض
    /// حماية OQ-1 (رفض أي حذف يُنتج رصيدًا سالبًا في أي نقطة زمنية) بالكامل إلى
    /// LedgerCalculator.applyingDeletion. عند النجاح فقط: إعادة التحميل عبر load()
    /// الموجودة أصلًا — لا تعديل محلي على allEntries بأي شكل (لا حالة UI وهمية).
    public func delete(id: String) {
        deleteErrorMessage = nil
        do {
            let result = try TransactionService.delete(id: id, in: context)
            switch result {
            case .success:
                load()
            case .failure(let error):
                deleteErrorMessage = message(for: error)
            }
        } catch {
            deleteErrorMessage = "تعذّر حذف العملية."
        }
    }

    /// تُستدعى من الـ View عند إغلاق تنبيه الخطأ، لتصفير الحالة بدل تركها معلَّقة.
    public func clearDeleteError() {
        deleteErrorMessage = nil
    }

    private func message(for error: TransactionServiceError) -> String {
        switch error {
        case .ledger(.wouldProduceNegativeBalance):
            return "لا يمكن حذف هذه العملية: سيؤدي ذلك إلى رصيد سالب في السجل."
        case .ledger(.transactionNotFound):
            return "تعذّر العثور على العملية."
        case .invalidAmount, .duplicateID:
            return "تعذّر حذف العملية."
        }
    }
}
