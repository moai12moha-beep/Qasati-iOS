/// عملية مالية مقترنة برصيدها المشتق بعد تنفيذها ضمن ترتيب زمني كامل.
///
/// هذا النوع، وليس `Transaction` نفسه، هو من يحمل `balanceAfter` —
/// وهو ناتج حساب مؤقت يُنتجه `LedgerCalculator.recompute(_:)` في كل مرة، ولا يُخزَّن أبدًا.
public struct LedgerEntry: Equatable, Sendable {
    public let transaction: Transaction
    public let balanceAfter: Int

    public init(transaction: Transaction, balanceAfter: Int) {
        self.transaction = transaction
        self.balanceAfter = balanceAfter
    }
}
