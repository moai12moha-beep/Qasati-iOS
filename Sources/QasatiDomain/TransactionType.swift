/// نوع العملية المالية.
///
/// القيم الخام (raw values) مطابقة حرفيًا للنصوص المستخدمة في qasati-standalone_2.html
/// (data-filter="deposit" / data-filter="withdraw"، وحقل `type` في transactions[]),
/// حفاظًا على التوافق مع ملفات النسخ الاحتياطي JSON القديمة القادمة من نسخة الويب.
public enum TransactionType: String, Codable, Equatable, Sendable, CaseIterable {
    case deposit
    case withdraw
}
