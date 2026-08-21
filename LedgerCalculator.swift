import Foundation

/// المصدر الوحيد لكل حسابات "قاصتي" المالية: الترتيب الزمني، الرصيد بعد كل عملية،
/// الملخص، وحماية سلامة الرصيد عند التعديل أو الحذف.
///
/// كل دالة هنا نقية (pure): تأخذ `[Transaction]` وتُعيد نتيجة محسوبة من الصفر،
/// بلا حالة داخلية وبلا أي تأثير جانبي — يطابق تعليق المصدر الأصلي حرفيًا:
/// "المصدر الأساسي للحقيقة هو سجل العمليات transactions[] — لا يُعتمد على متغير رصيد
/// منفصل بشكل دائم، يُعاد بناؤه دومًا".
public enum LedgerCalculator {

    public struct RecomputeResult: Equatable, Sendable {
        public let ordered: [LedgerEntry]
        public let finalBalance: Int
    }

    /// يطابق `recomputeBalances()`: ترتيب تصاعدي حسب `dateISO`، وعند تطابقه تمامًا
    /// يُستخدم `seq` كاسر تعادل، ثم تراكم الرصيد (+amount للإيداع، -amount للسحب) من الصفر.
    public static func recompute(_ transactions: [Transaction]) -> RecomputeResult {
        let sorted = transactions.sorted { lhs, rhs in
            if lhs.dateISO != rhs.dateISO {
                return lhs.dateISO < rhs.dateISO
            }
            return lhs.seq < rhs.seq
        }

        var running = 0
        var ordered: [LedgerEntry] = []
        ordered.reserveCapacity(sorted.count)
        for tx in sorted {
            running += tx.type == .deposit ? tx.amount : -tx.amount
            ordered.append(LedgerEntry(transaction: tx, balanceAfter: running))
        }

        return RecomputeResult(ordered: ordered, finalBalance: running)
    }

    /// يطابق `getSummary()`. `now` و`calendar` قابلان للحقن عمدًا (بدل قراءة `Date()` مباشرة
    /// داخليًا) لجعل حساب "ملخص هذا الشهر" حتميًا وقابلاً للاختبار.
    /// الافتراضي (`Calendar.current`) يطابق سلوك المصدر الذي يحسب الشهر بتوقيت الجهاز المحلي،
    /// وليس UTC.
    public static func summary(
        for transactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LedgerSummary {
        let finalBalance = recompute(transactions).finalBalance

        var totalDeposits = 0
        var totalWithdrawals = 0
        var countIn = 0
        var countOut = 0
        var monthNet = 0

        let thisMonth = monthKey(for: now, calendar: calendar)

        for tx in transactions {
            switch tx.type {
            case .deposit:
                totalDeposits += tx.amount
                countIn += 1
            case .withdraw:
                totalWithdrawals += tx.amount
                countOut += 1
            }
            if monthKey(for: tx.dateISO, calendar: calendar) == thisMonth {
                monthNet += tx.type == .deposit ? tx.amount : -tx.amount
            }
        }

        return LedgerSummary(
            balance: finalBalance,
            totalDeposits: totalDeposits,
            totalWithdrawals: totalWithdrawals,
            countIn: countIn,
            countOut: countOut,
            monthNet: monthNet
        )
    }

    /// يطابق الشرط في `handleWithdrawSubmit`: `amount > summary.balance` يُرفض.
    /// سحب يساوي الرصيد بالكامل مسموح (الرصيد الناتج صفر، وليس سالبًا).
    public static func canWithdraw(amount: Int, given transactions: [Transaction]) -> Bool {
        amount <= recompute(transactions).finalBalance
    }

    /// صحيح إذا أنتجت هذه القائمة رصيدًا سالبًا (< 0) في أي نقطة زمنية عبر كامل الترتيب
    /// التاريخي — وليس فقط في الرصيد النهائي.
    public static func wouldProduceNegativeBalance(_ transactions: [Transaction]) -> Bool {
        recompute(transactions).ordered.contains { $0.balanceAfter < 0 }
    }

    /// يطابق `updateTransaction()`: يبني سجلًا مرشَّحًا بالتعديل المطلوب، ويرفضه إن أدى
    /// إلى رصيد سالب في أي نقطة زمنية عبر السجل الكامل بعد التعديل.
    ///
    /// لا تتحقق هذه الدالة من أن `newAmount > 0` — تلك مسؤولية `AmountParser` عند نقطة
    /// النداء، تمامًا كما في المصدر الأصلي (فحص المبلغ في `saveEdit()` يسبق استدعاء
    /// `updateTransaction()`، وليس داخلها).
    public static func applyingEdit(
        to transactions: [Transaction],
        id: String,
        newAmount: Int,
        newNote: String
    ) -> Result<[Transaction], LedgerError> {
        guard transactions.contains(where: { $0.id == id }) else {
            return .failure(.transactionNotFound)
        }

        let candidate = transactions.map { tx -> Transaction in
            guard tx.id == id else { return tx }
            return Transaction(
                id: tx.id,
                type: tx.type,
                amount: newAmount,
                note: newNote,
                dateISO: tx.dateISO,
                seq: tx.seq
            )
        }

        if wouldProduceNegativeBalance(candidate) {
            return .failure(.wouldProduceNegativeBalance)
        }
        return .success(candidate)
    }

    /// قرار المنتج OQ-1: الحذف يخضع لنفس حماية التعديل تمامًا — لا يُسمح بأي مسار CRUD
    /// (لا تعديل ولا حذف) بإنتاج رصيد سالب في أي نقطة زمنية. هذا سلوك جديد مقارنة بالمصدر
    /// الأصلي (الذي كان يسمح بالحذف الحر بلا هذا التحقق)، بموافقة صريحة من المستخدم.
    public static func applyingDeletion(
        from transactions: [Transaction],
        id: String
    ) -> Result<[Transaction], LedgerError> {
        guard transactions.contains(where: { $0.id == id }) else {
            return .failure(.transactionNotFound)
        }

        let candidate = transactions.filter { $0.id != id }

        if wouldProduceNegativeBalance(candidate) {
            return .failure(.wouldProduceNegativeBalance)
        }
        return .success(candidate)
    }

    private struct MonthKey: Equatable {
        let year: Int
        let month: Int
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> MonthKey {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return MonthKey(year: comps.year ?? 0, month: comps.month ?? 0)
    }
}
