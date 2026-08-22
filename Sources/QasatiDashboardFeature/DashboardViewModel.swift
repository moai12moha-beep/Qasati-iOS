import Foundation
import Observation
import SwiftData
import QasatiDomain
import QasatiPersistence

/// يحمّل ملخص الدفتر الحالي من التخزين ويعرضه — بلا أي منطق مالي خاص به.
/// كل الحساب مُفوَّض بالكامل إلى `LedgerCalculator` (غير مُعدَّل)، وكل القراءة تمر عبر
/// `TransactionStore` (غير مُعدَّل). Phase 4 قراءة فقط: لا إضافة، لا تعديل، لا حذف هنا.
@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var summary: LedgerSummary
    public private(set) var loadError: Error?

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
        self.summary = LedgerSummary(
            balance: 0,
            totalDeposits: 0,
            totalWithdrawals: 0,
            countIn: 0,
            countOut: 0,
            monthNet: 0
        )
    }

    /// يجلب كل العمليات المخزَّنة ويعيد حساب الملخص من الصفر — يطابق تمامًا فلسفة
    /// "أعد الحساب دومًا من سجل العمليات" المُطبَّقة في LedgerCalculator نفسه.
    public func load() {
        do {
            let transactions = try TransactionStore.fetchAll(from: context)
            summary = LedgerCalculator.summary(for: transactions)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}
