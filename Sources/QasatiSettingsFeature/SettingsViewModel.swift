import Foundation
import Observation
import SwiftData
import QasatiPersistence
import QasatiBackupService

/// منسِّق شاشة الإعدادات: تصدير/استيراد النسخة الاحتياطية، ومسح كل البيانات — كل ذلك
/// عبر الطبقات الموجودة بالفعل (BackupService، TransactionStore) بلا أي تكرار لمنطق
/// الترميز/التحقق/التخزين. لا وصول مباشر لـ SwiftData/PersistedTransaction هنا.
@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var statusMessage: String?
    public private(set) var isError = false

    /// السبب التقني الفعلي لآخر فشل استيراد (للتصحيح/الاختبار فقط) — لا يُعرَض
    /// للمستخدم أبدًا؛ الرسالة الظاهرة له عامة دومًا (راجع message للمستخدم أدناه).
    public private(set) var lastImportError: BackupError?

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// يُصدِّر البيانات الحالية إلى ملف JSON مؤقت جاهز للمشاركة، ويُعيد مساره.
    /// لا يُكرِّر ترميز JSON — يستدعي BackupService.export فقط.
    public func exportFile() -> URL? {
        guard let data = try? BackupService.export(from: context) else {
            statusMessage = "تعذّر تصدير البيانات."
            isError = true
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let filename = "qasati-backup-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            statusMessage = "تعذّر تصدير البيانات."
            isError = true
            return nil
        }

        statusMessage = "تم تصدير نسخة احتياطية بنجاح."
        isError = false
        return url
    }

    /// يستورد نسخة احتياطية من بيانات خام. لا يُكرِّر أي تحقق — يستدعي
    /// BackupService.importBackup فقط، ويُترجم أي فشل إلى رسالة عامة واحدة للمستخدم،
    /// مع الاحتفاظ بالسبب التقني الدقيق داخليًا في lastImportError.
    public func importData(_ data: Data) {
        let result = BackupService.importBackup(data, into: context)
        switch result {
        case .success(let count):
            lastImportError = nil
            statusMessage = "تم استيراد \(count) عملية بنجاح."
            isError = false
        case .failure(let error):
            lastImportError = error
            statusMessage = Self.genericImportFailureMessage
            isError = true
        }
    }

    /// يُستدعى عندما يتعذّر حتى قراءة الملف المُختار (قبل أن تصل بياناته إلى
    /// BackupService أصلًا) — نفس الرسالة العامة، تمامًا كأي فشل استيراد آخر.
    public func reportImportReadFailure() {
        lastImportError = nil
        statusMessage = Self.genericImportFailureMessage
        isError = true
    }

    /// يمسح كل البيانات عبر TransactionStore.replaceAll(with: [], in:) الموجودة
    /// بالفعل — بلا أي بدائية تخزين جديدة.
    public func wipeAllData() {
        do {
            try TransactionStore.replaceAll(with: [], in: context)
            statusMessage = "تم حذف جميع البيانات من هذا الجهاز."
            isError = false
        } catch {
            statusMessage = "تعذّر حذف البيانات."
            isError = true
        }
    }

    public func clearStatus() {
        statusMessage = nil
        isError = false
    }

    private static let genericImportFailureMessage = "ملف غير صالح. يرجى اختيار نسخة احتياطية صحيحة من قاصتي."
}
