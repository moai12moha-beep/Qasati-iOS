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
    init() {
        do {
            let schema = Schema([PersistedTransaction.self])
            let configuration = ModelConfiguration(schema: schema)
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
