import Foundation
import SwiftData

/// نموذج التخزين (persistence model) لعملية مالية واحدة، منفصل تمامًا عن
/// `Transaction` في طبقة `QasatiDomain`.
///
/// عمدًا نوع مختلف عن `Transaction`: `Transaction` قيمة (struct) نقية مستقلة عن
/// SwiftData، بينما هذا مرجع (class) مُدار بواسطة SwiftData لأغراض التخزين فقط.
/// كل حقل يُخزَّن بأبسط تمثيل ممكن (بلا تحويلات ضمنية أو فقدان دقة):
/// - `type` يُخزَّن كـ raw value نصي (`TransactionType.rawValue`)، وليس كـ enum مباشرة،
///   لتفادي أي افتراضات غير مؤكَّدة حول دعم SwiftData لتخزين الـ enums في هذا الإصدار.
/// - `dateISO` يُخزَّن كـ `Date` أصلي مباشرة (بلا تحويل نصي وسيط)، لتفادي أي فقدان دقة
///   ناتج عن round-trip عبر نص ISO-8601.
/// - `seq` يبقى `Double` كما هو في طبقة Domain، بلا تقريب.
@Model
public final class PersistedTransaction {
    @Attribute(.unique) public var id: String
    public var type: String
    public var amount: Int
    public var note: String
    public var dateISO: Date
    public var seq: Double

    public init(id: String, type: String, amount: Int, note: String, dateISO: Date, seq: Double) {
        self.id = id
        self.type = type
        self.amount = amount
        self.note = note
        self.dateISO = dateISO
        self.seq = seq
    }
}
