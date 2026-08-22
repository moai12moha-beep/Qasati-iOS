import SwiftUI
import QasatiDomain

/// شاشة اللوحة الرئيسية: الرصيد الحالي + ست بطاقات إحصائية. عرض بحت لـ
/// `DashboardViewModel.summary` — بلا أي تفاعل CRUD، بلا زر راتب سريع (مؤجَّل لمرحلة
/// نموذج الإيداع)، بلا أي منطق مالي داخل الـ View نفسها.
///
/// عمدًا بلا أي استخدام لـ UIKit/AppKit (مثل UIColor.secondarySystemBackground):
/// حزمة الحزمة الحالية تدعم iOS وmacOS معًا (platforms في Package.swift)، وAPIs خاصة
/// بمنصة واحدة كانت ستفشل عند بناء الهدف لمنصة أخرى. كل الألوان/الأنماط هنا من
/// SwiftUI الأساسي فقط، متوافقة عبر المنصتين.
///
/// `@MainActor` هنا مطلوبة صراحة: `DashboardViewModel` معزول على @MainActor، وخصائصي
/// المساعدة الخاصة (balanceSection/statsGrid/statCard) ليست جزءًا من متطلبات بروتوكول
/// View فتكتسب عزل MainActor تلقائيًا كما يكتسبه body — لذا يجب تعليم النوع كاملًا
/// @MainActor ليتطابق عزل كل أعضائه مع عزل summary الذي تقرأه.
@MainActor
public struct DashboardView: View {
    let viewModel: DashboardViewModel

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                balanceSection
                statsGrid
            }
            .padding()
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            viewModel.load()
        }
    }

    private var balanceSection: some View {
        VStack(spacing: 8) {
            Text("💰 الرصيد الحالي")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(IQDFormatter.formatNumberOnly(viewModel.summary.balance)) د.ع")
                .font(.system(size: 34, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            statCard(title: "إجمالي الإيداعات", value: IQDFormatter.formatIQD(viewModel.summary.totalDeposits))
            statCard(title: "إجمالي السحوبات", value: IQDFormatter.formatIQD(viewModel.summary.totalWithdrawals))
            statCard(title: "الرصيد الحالي", value: IQDFormatter.formatIQD(viewModel.summary.balance))
            statCard(title: "ملخص هذا الشهر", value: IQDFormatter.formatSignedMonthNet(viewModel.summary.monthNet))
            statCard(title: "عدد الإيداعات", value: "\(viewModel.summary.countIn)")
            statCard(title: "عدد السحوبات", value: "\(viewModel.summary.countOut)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
