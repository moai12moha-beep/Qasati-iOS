import SwiftUI
import SwiftData
import QasatiPersistence

@main
struct QasatiApp: App {
    private let container: ModelContainer?
    private let containerError: Error?

    /// ModelContainer واحد فقط لعمر التطبيق كله — يُنشأ هنا مرة واحدة، ويُحقَن عبر
    /// .modelContainer(container) في body، فتصل كل الشاشات لنفس ModelContext المشترك عبر
    /// @Environment(\.modelContext) الخاصة بـ SwiftUI. لا حاوية إنتاجية أخرى تُنشأ في أي
    /// شاشة على الإطلاق.
    ///
    /// عند فشل الإنشاء: لا بيانات فارغة صامتة، ولا fatalError — تُعرَض
    /// ModelContainerFailureView بدل الجذر الحقيقي فقط.
    ///
    /// عند التشغيل تحت اختبارات الواجهة فقط (وسيطة الإطلاق "UI-TESTING"، التي تضبطها
    /// QasatiAppUITests حصرًا): تخزين في الذاكرة فقط، بلا لمس ملف التخزين الحقيقي على
    /// القرص إطلاقًا — يضمن عزلًا كاملًا بين كل تشغيلة اختبار واجهة (بيانات فارغة تمامًا
    /// من جديد مع كل app.launch()، بلا أي اعتماد على بيانات خلَّفها اختبار سابق)، بلا
    /// حاجة لحساب Apple ID/iCloud حقيقي أو جهاز فعلي. لا يُغيّر هذا شيئًا في التشغيل
    /// الإنتاجي العادي (isStoredInMemoryOnly يبقى false دومًا هناك).
    init() {
        do {
            let schema = Schema([PersistedTransaction.self])
            let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-TESTING")
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
            container = try ModelContainer(for: schema, configurations: [configuration])
            containerError = nil
        } catch {
            container = nil
            containerError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .modelContainer(container)
            } else {
                ModelContainerFailureView(error: containerError)
            }
        }
    }
}
