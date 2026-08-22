import Foundation
import Observation
import SwiftData
import QasatiDomain
import QasatiPersistence

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

    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// يجلب كل العمليات ويعيد بناء الترتيب/الرصيد من الصفر — يطابق فلسفة "أعد الحساب
    /// دومًا من سجل العمليات" المُطبَّقة في LedgerCalculator نفسه.
    public func load() {
        let transactions = (try? TransactionStore.fetchAll(from: context)) ?? []
        allEntries = LedgerCalculator.recompute(transactions).ordered
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
}
