import SwiftUI

/// تُعرَض بدل الجذر الحقيقي فقط إن فشل إنشاء ModelContainer الوحيد — بلا بيانات فارغة
/// صامتة، وبلا انهيار (fatalError) لخطأ تخزين قابل للعرض على المستخدم.
struct ModelContainerFailureView: View {
    let error: Error?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("تعذّر فتح قاعدة البيانات")
                .font(.title2.weight(.bold))
            Text("تعذّر على قاصتي فتح ملف التخزين المحلي. أعد تشغيل التطبيق، وإن استمرت المشكلة فقد يكون التخزين تالفًا.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
    }
}
