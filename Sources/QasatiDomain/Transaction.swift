import Foundation

/// عملية مالية واحدة (إيداع أو سحب).
///
/// يطابق شكل الكائن المخزَّن في `localStorage["qasati_transactions_v1"]` في qasati-standalone_2.html:
/// `{id, type, amount, note, dateISO, seq}`. لا يحتوي هذا النوع على `balanceAfter` عمدًا —
/// الرصيد بعد كل عملية مشتق دائمًا عبر `LedgerCalculator`، وليس جزءًا من حالة العملية المخزَّنة،
/// تمامًا كما في المصدر الأصلي (راجع Phase 1، البند 6).
public struct Transaction: Identifiable, Equatable, Sendable {
    /// معرّف العملية. تُحافَظ عليه كما هو عند استيراد بيانات قديمة من نسخة الويب (لا تُعاد كتابته).
    public let id: String

    public var type: TransactionType

    /// المبلغ بالدينار العراقي، عدد صحيح موجب فقط (لا كسور، لا قيم سالبة أو صفرية).
    /// التحقق من الصحة مسؤولية `AmountParser`، وليس مسؤولية هذا النوع.
    public var amount: Int

    public var note: String

    /// تاريخ ووقت إنشاء العملية. لا يتغيّر أبدًا بعد الإنشاء — التعديل يغيّر amount/note فقط،
    /// تمامًا كما ينص التلميح الظاهر في نافذة التعديل بنسخة الويب.
    public let dateISO: Date

    /// كاسر تعادل للترتيب عند تطابق dateISO تمامًا. يُبقى على شكله الأصلي (Double) للتوافق
    /// مع قيم seq القديمة المولَّدة في JS بصيغة `Date.now() + Math.random()`.
    public let seq: Double

    public init(id: String, type: TransactionType, amount: Int, note: String, dateISO: Date, seq: Double) {
        self.id = id
        self.type = type
        self.amount = amount
        self.note = note
        self.dateISO = dateISO
        self.seq = seq
    }
}

extension Transaction: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, amount, note, dateISO, seq
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        amount = try container.decode(Int.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""

        let dateString = try container.decode(String.self, forKey: .dateISO)
        guard let date = Transaction.isoFormatterWithFractionalSeconds.date(from: dateString)
            ?? Transaction.isoFormatterWithoutFractionalSeconds.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .dateISO,
                in: container,
                debugDescription: "Invalid ISO-8601 date string: \(dateString)"
            )
        }
        dateISO = date

        seq = try container.decode(Double.self, forKey: .seq)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(amount, forKey: .amount)
        try container.encode(note, forKey: .note)
        try container.encode(Transaction.isoFormatterWithFractionalSeconds.string(from: dateISO), forKey: .dateISO)
        try container.encode(seq, forKey: .seq)
    }

    /// يطابق صيغة إخراج `Date.prototype.toISOString()` في JavaScript بالضبط،
    /// مثل: "2026-08-21T14:23:45.123Z".
    static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// احتياط دفاعي فقط لملفات قديمة/معدَّلة يدويًا بلا أجزاء الثانية الكسرية.
    static let isoFormatterWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
