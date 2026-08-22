import Foundation
import SwiftData
import QasatiDomain
import QasatiPersistence

/// طبقة تنسيق CRUD على العمليات المالية: تربط `QasatiDomain` (قواعد العمل) بـ
/// `QasatiPersistence` (التخزين) دون أن تعيد تعريف أي منهما.
///
/// لا يوجد هنا أي منطق مالي جديد — كل قرار حول صحة الرصيد يُفوَّض بالكامل إلى
/// `LedgerCalculator`، وكل تحقق من صحة المبلغ يُفوَّض إلى `AmountParser`. هذه الطبقة
/// فقط: تجلب الحالة الحالية، تستدعي التحقق الصحيح، ثم تُنفّذ التخزين إن نجح التحقق.
public enum TransactionService {

    /// يضيف عملية جديدة.
    /// يُرفض إن: كان المبلغ غير صالح، أو كان المعرّف مستخدَمًا بالفعل، أو كانت الإضافة
    /// ستُنتج رصيدًا سالبًا في أي نقطة زمنية (يُحسَب عبر LedgerCalculator دون تعديله).
    public static func add(
        _ transaction: Transaction,
        in context: ModelContext
    ) throws -> Result<Void, TransactionServiceError> {
        guard AmountParser.isValidAmount(transaction.amount) else {
            return .failure(.invalidAmount)
        }

        let existing = try TransactionStore.fetchAll(from: context)

        guard !existing.contains(where: { $0.id == transaction.id }) else {
            return .failure(.duplicateID)
        }

        let candidate = existing + [transaction]
        if LedgerCalculator.wouldProduceNegativeBalance(candidate) {
            return .failure(.ledger(.wouldProduceNegativeBalance))
        }

        try TransactionStore.save(transaction, in: context)
        return .success(())
    }

    /// يعدّل مبلغ/ملاحظة عملية موجودة بمعرّفها. لا يغيّر dateISO/seq أبدًا (Transaction
    /// نفسه لا يسمح بذلك أصلًا — الحقلان `let`). يُحدّث السجل المخزَّن في مكانه، ولا يُنشئ
    /// سجلًا مكررًا أبدًا.
    public static func edit(
        id: String,
        newAmount: Int,
        newNote: String,
        in context: ModelContext
    ) throws -> Result<Void, TransactionServiceError> {
        guard AmountParser.isValidAmount(newAmount) else {
            return .failure(.invalidAmount)
        }

        let existing = try TransactionStore.fetchAll(from: context)
        let result = LedgerCalculator.applyingEdit(to: existing, id: id, newAmount: newAmount, newNote: newNote)

        switch result {
        case .failure(let ledgerError):
            return .failure(.ledger(ledgerError))
        case .success:
            do {
                try TransactionStore.updateFields(id: id, amount: newAmount, note: newNote, in: context)
            } catch is TransactionStoreError {
                // عدم اتساق بين ما وجدته طبقة Domain (بحثت في نفس القائمة المجلوبة للتو)
                // وما وجدته طبقة التخزين لا يُفترض أن يحدث ضمن هذا السياق المتزامن الواحد.
                // نُعبّر عنه بأقرب حالة موجودة بدل اختراع حالة جديدة لسيناريو لا يجب أن يقع فعليًا.
                return .failure(.ledger(.transactionNotFound))
            }
            return .success(())
        }
    }

    /// يحذف عملية بمعرّفها. يُرفض إن كانت غير موجودة، أو إن كان حذفها سيُنتج رصيدًا سالبًا
    /// في أي نقطة زمنية لاحقة (قرار المنتج OQ-1، محسوب عبر LedgerCalculator دون تعديله).
    public static func delete(
        id: String,
        in context: ModelContext
    ) throws -> Result<Void, TransactionServiceError> {
        let existing = try TransactionStore.fetchAll(from: context)
        let result = LedgerCalculator.applyingDeletion(from: existing, id: id)

        switch result {
        case .failure(let ledgerError):
            return .failure(.ledger(ledgerError))
        case .success:
            do {
                try TransactionStore.delete(id: id, in: context)
            } catch is TransactionStoreError {
                return .failure(.ledger(.transactionNotFound))
            }
            return .success(())
        }
    }
}

/// أخطاء طبقة التنسيق. تُغلِّف `LedgerError` القادم من Domain دون إعادة تعريفه،
/// وتضيف فقط حالتين لا يعبّر عنهما نموذج الأخطاء الحالي أصلًا:
/// مبلغ غير صالح (شرط إدخال، وليس شرط رصيد)، ومعرّف مكرر (شرط هوية، وليس شرط رصيد).
public enum TransactionServiceError: Error, Equatable, Sendable {
    case invalidAmount
    case duplicateID
    case ledger(LedgerError)
}
