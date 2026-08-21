import Foundation
import SwiftData
import QasatiDomain

/// عمليات تخزين بحتة على `PersistedTransaction` عبر `ModelContext` مُمرَّر من الخارج،
/// بالإضافة إلى التحويل بين طبقتي Domain وPersistence.
///
/// عمدًا لا يوجد هنا أي منطق CRUD/تنسيق (لا تعديل، لا حذف، لا دمج) — هذا خارج نطاق
/// Phase 2 المعتمد. فقط: حفظ، واسترجاع الكل، وتحويل بلا فقدان بين النوعين.
public enum TransactionStore {

    /// تحويل من نموذج Domain إلى نموذج التخزين. بلا أي تحويل ضمني أو تقريب.
    public static func makePersisted(from transaction: Transaction) -> PersistedTransaction {
        PersistedTransaction(
            id: transaction.id,
            type: transaction.type.rawValue,
            amount: transaction.amount,
            note: transaction.note,
            dateISO: transaction.dateISO,
            seq: transaction.seq
        )
    }

    /// تحويل من نموذج التخزين إلى نموذج Domain. يُعيد `nil` إن كانت قيمة `type`
    /// المخزَّنة غير مطابقة لأي حالة معروفة من `TransactionType` (بيانات تالفة) —
    /// بدل افتراض قيمة افتراضية بصمت.
    public static func makeTransaction(from persisted: PersistedTransaction) -> Transaction? {
        guard let type = TransactionType(rawValue: persisted.type) else { return nil }
        return Transaction(
            id: persisted.id,
            type: type,
            amount: persisted.amount,
            note: persisted.note,
            dateISO: persisted.dateISO,
            seq: persisted.seq
        )
    }

    /// يحفظ عملية واحدة في السياق المُمرَّر. إدراج بسيط فقط — لا يبحث عن سجل موجود
    /// بنفس المعرّف ولا يُحدّثه (منطق upsert/CRUD مؤجَّل لمرحلة لاحقة معتمَدة).
    public static func save(_ transaction: Transaction, in context: ModelContext) throws {
        context.insert(makePersisted(from: transaction))
        try context.save()
    }

    /// يسترجع كل العمليات المخزَّنة في السياق المُمرَّر، محوَّلة إلى نموذج Domain.
    /// أي سجل تالف (type غير معروف) يُستبعَد بصمت من النتيجة بدل أن يُفشل الاسترجاع كله.
    public static func fetchAll(from context: ModelContext) throws -> [Transaction] {
        let descriptor = FetchDescriptor<PersistedTransaction>()
        let persisted = try context.fetch(descriptor)
        return persisted.compactMap(makeTransaction(from:))
    }
}
