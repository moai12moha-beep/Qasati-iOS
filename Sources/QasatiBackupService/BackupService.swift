import Foundation
import SwiftData
import QasatiDomain
import QasatiPersistence

/// أخطاء التحقق من النسخة الاحتياطية عند الاستيراد. كل حالة تعني: رُفض الاستيراد
/// **بالكامل**، ولم تُلمَس البيانات المخزَّنة الحالية إطلاقًا — لا استيراد جزئي أبدًا.
public enum BackupError: Error, Equatable, Sendable {
    case malformedJSON
    case unsupportedApp
    case unsupportedVersion
    case emptyTransactions
    case invalidTransactionRecord
    case duplicateTransactionID
    case persistenceFailure
}

/// تصدير/استيراد نسخة احتياطية كاملة. لا منطق مالي هنا إطلاقًا: التحقق من صحة المبلغ
/// عبر `AmountParser` (غير مُعدَّل) فقط، والتخزين عبر `TransactionStore.fetchAll`/
/// `.replaceAll` (غير مُعدَّلين في سلوكهما الأساسي، فقط `replaceAll` مُضافة حديثًا) فقط.
///
/// عمدًا: **كل** خطوات التحقق تحدث في الذاكرة أولًا، قبل أي استدعاء لطبقة التخزين على
/// الإطلاق. `TransactionStore.replaceAll` لا يُستدعى إلا بعد نجاح كل خطوة تحقق — هذا
/// وحده يضمن عدم لمس البيانات الحالية إطلاقًا عند رفض الاستيراد، بلا حاجة لأي منطق
/// "تراجع" (rollback) صريح.
public enum BackupService {
    public static let supportedApp = "qasati"
    public static let supportedVersion = 1

    /// يُصدِّر كل العمليات المخزَّنة حاليًا كنسخة احتياطية بصيغة JSON.
    public static func export(from context: ModelContext) throws -> Data {
        let transactions = try TransactionStore.fetchAll(from: context)
        let payload = BackupPayload(
            app: supportedApp,
            version: supportedVersion,
            exportedAt: Date(),
            transactions: transactions
        )
        return try makeEncoder().encode(payload)
    }

    /// يستورد نسخة احتياطية من بيانات JSON خام. يُرفض الاستيراد بالكامل عند أول خطوة
    /// تحقق فاشلة: صيغة JSON، ثم app/version، ثم عدم-الفراغ، ثم صحة كل مبلغ، ثم عدم
    /// تكرار المعرّفات ضمن الملف نفسه. الاستبدال الفعلي للبيانات لا يحدث إلا بعد نجاح
    /// كل هذه الخطوات معًا.
    public static func importBackup(_ data: Data, into context: ModelContext) -> Result<Int, BackupError> {
        let payload: BackupPayload
        do {
            payload = try makeDecoder().decode(BackupPayload.self, from: data)
        } catch {
            return .failure(.malformedJSON)
        }

        guard payload.app == supportedApp else {
            return .failure(.unsupportedApp)
        }
        guard payload.version == supportedVersion else {
            return .failure(.unsupportedVersion)
        }
        guard !payload.transactions.isEmpty else {
            return .failure(.emptyTransactions)
        }
        guard payload.transactions.allSatisfy({ AmountParser.isValidAmount($0.amount) }) else {
            return .failure(.invalidTransactionRecord)
        }
        let ids = payload.transactions.map(\.id)
        guard Set(ids).count == ids.count else {
            return .failure(.duplicateTransactionID)
        }

        do {
            try TransactionStore.replaceAll(with: payload.transactions, in: context)
        } catch {
            return .failure(.persistenceFailure)
        }

        return .success(payload.transactions.count)
    }

    /// يطابق صيغة إخراج `Date.prototype.toISOString()` في JavaScript بالضبط —
    /// نفس الصيغة المستخدَمة في `Transaction` (Phase 1). يُعاد استخدام منسِّقيّ
    /// `Transaction` مباشرة (Phase 15) بدل نسخة مكرَّرة محليًا، بعد أن أصبحا `public` —
    /// نفس خيارات التنسيق والناتج بالضبط، بلا أي تغيير سلوكي.
    ///
    /// إستراتيجية تاريخ مخصَّصة تُطبَّق فقط على `exportedAt` (النوع الوحيد الفعلي من
    /// `Date` في هذه الشجرة) — `Transaction.dateISO` يُفكَّك يدويًا كنص داخل `Transaction`
    /// نفسها، فلا يتأثر بإستراتيجية الترميز/فك الترميز الخاصة بهذا المُرمِّز إطلاقًا.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Transaction.isoFormatterWithFractionalSeconds.string(from: date))
        }
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = Transaction.isoFormatterWithFractionalSeconds.date(from: string)
                ?? Transaction.isoFormatterWithoutFractionalSeconds.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date string: \(string)"
                )
            }
            return date
        }
        return decoder
    }
}
