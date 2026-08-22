import Foundation
import Observation
import SwiftData
import QasatiDomain
import QasatiTransactionService

/// منطق نموذج واحد قابل لإعادة الاستخدام لكلا شاشتي الإيداع والسحب — الفرق الوحيد
/// بينهما هو `type`، وليس أي منطق إضافي: كلاهما إدخال مبلغ + ملاحظة اختيارية + إرسال،
/// وكلاهما يُفوَّض بالكامل إلى `TransactionService.add` (غير مُعدَّل) لكل قرار مالي،
/// بما في ذلك رفض السحب الذي يتجاوز الرصيد (يُعبَّر عنه بـ wouldProduceNegativeBalance
/// نفسها التي تحمي الإيداع أيضًا — لا حاجة لمسار تحقق منفصل للسحب).
@MainActor
@Observable
public final class TransactionFormViewModel {
    public let type: TransactionType

    public var amountText: String = ""
    public var noteText: String = ""
    public private(set) var errorMessage: String?
    public private(set) var didSaveSuccessfully = false

    private let context: ModelContext

    public init(type: TransactionType, context: ModelContext) {
        self.type = type
        self.context = context
    }

    public func submit() {
        errorMessage = nil
        didSaveSuccessfully = false

        guard let amount = AmountParser.parse(amountText), AmountParser.isValidAmount(amount) else {
            errorMessage = "يرجى إدخال مبلغ صحيح."
            return
        }

        let transaction = Transaction.creatingNew(type: type, amount: amount, note: noteText)

        do {
            let result = try TransactionService.add(transaction, in: context)
            switch result {
            case .success:
                amountText = ""
                noteText = ""
                didSaveSuccessfully = true
            case .failure(let error):
                errorMessage = message(for: error)
            }
        } catch {
            errorMessage = "تعذّر حفظ العملية."
        }
    }

    private func message(for error: TransactionServiceError) -> String {
        switch error {
        case .ledger(.wouldProduceNegativeBalance):
            return type == .withdraw
                ? "الرصيد غير كافٍ لإتمام عملية السحب."
                : "يرجى إدخال مبلغ صحيح."
        case .invalidAmount:
            return "يرجى إدخال مبلغ صحيح."
        case .duplicateID, .ledger(.transactionNotFound):
            return "تعذّر حفظ العملية."
        }
    }
}
