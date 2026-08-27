import SwiftUI
import UniformTypeIdentifiers

/// شاشة الإعدادات: المظهر، الخصوصية، النسخ الاحتياطي (تصدير/استيراد)، ومسح كل
/// البيانات. عرض بحت لـ AppPreferences/SettingsViewModel — لا وصول مباشر لـ
/// SwiftData، ولا تكرار لمنطق BackupService/TransactionStore.
///
/// `@MainActor` على النوع كاملًا لنفس السبب المكتشَف في إصلاح Phase 4: الخصائص
/// المساعدة الخاصة هنا ليست جزءًا من متطلبات بروتوكول View فلا تكتسب عزل MainActor
/// تلقائيًا، بينما AppPreferences/SettingsViewModel معزولان على @MainActor.
@MainActor
public struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var viewModel: SettingsViewModel

    /// المظهر الفعلي الحالي كما يراه SwiftUI (النظام، ما لم يوجد تفضيل صريح مُطبَّق
    /// بالفعل في مكان أعلى في الشجرة) — يُمرَّر إلى toggleTheme فقط كنقطة انطلاق عندما
    /// لا يوجد تفضيل مخزَّن بعد؛ يُتجاهَل تمامًا بمجرد وجود تفضيل صريح.
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var exportedFileURL: URL?
    @State private var isImporterPresented = false
    @State private var isWipeConfirmationPresented = false
    @State private var isFinalWipeWarningPresented = false

    public init(preferences: AppPreferences, viewModel: SettingsViewModel) {
        self.preferences = preferences
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            themeSection
            privacySection
            backupSection
            dangerSection
        }
        .environment(\.layoutDirection, .rightToLeft)
        .alert(
            viewModel.isError ? "خطأ" : "تم",
            isPresented: Binding(
                get: { viewModel.statusMessage != nil },
                set: { isPresented in if !isPresented { viewModel.clearStatus() } }
            )
        ) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text(viewModel.statusMessage ?? "")
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let didStartAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing { url.stopAccessingSecurityScopedResource() }
                }
                if let data = try? Data(contentsOf: url) {
                    viewModel.importData(data)
                } else {
                    viewModel.reportImportReadFailure()
                }
            case .failure:
                viewModel.reportImportReadFailure()
            }
        }
    }

    private var themeSection: some View {
        Section("المظهر") {
            Toggle(isOn: Binding(
                get: { preferences.colorScheme == .dark },
                set: { _ in
                    preferences.toggleTheme(systemAppearance: systemColorScheme == .dark ? .dark : .light)
                }
            )) {
                Text("🌙 الوضع الليلي")
            }
        }
    }

    private var privacySection: some View {
        Section("الخصوصية") {
            Toggle(isOn: Binding(
                get: { preferences.isBalanceHidden },
                set: { _ in preferences.togglePrivacy() }
            )) {
                Text("👁️ إخفاء الرصيد")
            }
        }
    }

    private var backupSection: some View {
        Section("الإعدادات والنسخ الاحتياطي") {
            settingsRow(
                title: "تصدير البيانات",
                subtitle: "تنزيل ملف JSON يحتوي جميع عملياتك"
            ) {
                Button("⬇️ تصدير") {
                    exportedFileURL = viewModel.exportFile()
                }
            }

            if let exportedFileURL {
                ShareLink(item: exportedFileURL) {
                    Text("مشاركة النسخة الاحتياطية")
                }
            }

            settingsRow(
                title: "استيراد البيانات",
                subtitle: "استعادة بياناتك من ملف JSON سابق"
            ) {
                Button("⬆️ استيراد") {
                    isImporterPresented = true
                }
            }
        }
    }

    private var dangerSection: some View {
        Section {
            settingsRow(
                title: "مسح جميع البيانات",
                subtitle: "حذف نهائي لكل العمليات والرصيد من هذا الجهاز"
            ) {
                Button("🗑️ مسح جميع البيانات", role: .destructive) {
                    isWipeConfirmationPresented = true
                }
            }
        }
        .confirmationDialog(
            "مسح جميع البيانات",
            isPresented: $isWipeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("متابعة", role: .destructive) {
                isFinalWipeWarningPresented = true
            }
            Button("إلغاء", role: .cancel) {}
        }
        .alert("🚨 تحذير نهائي", isPresented: $isFinalWipeWarningPresented) {
            Button("حذف جميع البيانات", role: .destructive) {
                viewModel.wipeAllData()
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("تحذير: سيتم حذف جميع العمليات والرصيد بشكل نهائي من هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.")
        }
    }

    private func settingsRow<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            trailing()
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
