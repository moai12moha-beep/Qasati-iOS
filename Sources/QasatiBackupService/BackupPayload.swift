import Foundation
import QasatiDomain

/// بنية النسخة الاحتياطية الكاملة — تطابق صيغة qasati-standalone_2.html حرفيًا:
/// {app, version, exportedAt, transactions}. `transactions` يعيد استخدام Codable
/// الخاص بـ `Transaction` مباشرة (QasatiDomain، Phase 1) بلا أي تكرار لتعريف حقوله.
///
/// Codable هنا مُصنَّع تلقائيًا (بلا تخصيص) — تنسيق `exportedAt` بصيغة ISO-8601 هو
/// مسؤولية الـ JSONEncoder/JSONDecoder المُهيَّأين صراحةً في `BackupService`، وليس هذا
/// النوع. هذا لا يتعارض مع تنسيق `Transaction.dateISO` الخاص: ذلك الحقل يُفكَّك يدويًا
/// كنص داخل `Transaction` نفسها ولا يمر عبر آلية فك ترميز `Date` العامة إطلاقًا.
public struct BackupPayload: Codable, Equatable, Sendable {
    public let app: String
    public let version: Int
    public let exportedAt: Date
    public let transactions: [Transaction]

    public init(app: String, version: Int, exportedAt: Date, transactions: [Transaction]) {
        self.app = app
        self.version = version
        self.exportedAt = exportedAt
        self.transactions = transactions
    }
}
