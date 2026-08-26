import Foundation
import Observation
import SwiftData
import QasatiDomain
import QasatiTransactionService

/// منطق نموذج تعديل عملية موجودة. `id`/`type`/`dateISO` للقراءة فقط — `Transaction`
/// نفسه لا يسمح بتغييرها أصلًا (حقول `let`)، و`TransactionService.edit` (غير مُعدَّل)
/// لا يغيّرها كذلك. فقط `amount`/`note` قابلان للتعديل.
@MainActor
@Observable
public final class EditTransactionViewModel {
    public let transactionID: String
    public let type: TransactionType
    public let originalDateISO: Date

    public var amountText: String
    public var noteText: String
    public private(set) var errorMessage: String?
    public private(set) var didSaveSuccessfully = false

    private let context: ModelContext

    public init(transaction: Transaction, context: ModelContext) {
        self.transactionID = transaction.id
        self.type = transaction.type
        self.originalDateISO = transaction.dateISO
        self.amountText = String(transaction.amount)
        self.noteText = transaction.note
        self.context = context
    }

    /// يطابق saveEdit() في qasati-standalone_2.html: يتحقق من المبلغ، ثم يُفوّض القرار
    /// المالي بالكامل إلى TransactionService.edit (غير مُعدَّل)، الذي يستدعي بدوره
    /// LedgerCalculator.applyingEdit دون أي إعادة تنفيذ محلية لمنطق الرصيد.
    public func save() {
        errorMessage = nil
        didSaveSuccessfully = false

        guard let amount = AmountParser.parse(amountText), AmountParser.isValidAmount(amount) else {
            errorMessage = "يرجى إدخال مبلغ صحيح."
            return
        }

        do {
            let result = try TransactionService.edit(
                id: transactionID,
                newAmount: amount,
                newNote: noteText,
                in: context
            )
            switch result {
            case .success:
                didSaveSuccessfully = true
            case .failure(let error):
                errorMessage = message(for: error)
            }
        } catch {
            errorMessage = "تعذّر حفظ التعديلات."
        }
    }

    private func message(for error: TransactionServiceError) -> String {
        switch error {
        case .ledger(.wouldProduceNegativeBalance):
            return "لا يمكن حفظ التعديل: سيؤدي إلى رصيد سالب في السجل."
        case .ledger(.transactionNotFound):
            return "تعذّر العثور على العملية."
        case .invalidAmount:
            return "يرجى إدخال مبلغ صحيح."
        case .duplicateID:
            return "تعذّر حفظ التعديلات."
        }
    }
}
