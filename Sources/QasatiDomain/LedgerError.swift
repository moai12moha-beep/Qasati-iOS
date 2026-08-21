public enum LedgerError: Error, Equatable, Sendable {
    /// لا توجد عملية بهذا المعرّف ضمن السجل الحالي.
    case transactionNotFound

    /// تنفيذ هذا التعديل أو الحذف كان سيُنتج رصيدًا سالبًا في نقطة زمنية واحدة على الأقل
    /// عبر السجل الكامل — وليس فقط في الرصيد النهائي. مرفوض حسب قرار المنتج OQ-1.
    case wouldProduceNegativeBalance
}
