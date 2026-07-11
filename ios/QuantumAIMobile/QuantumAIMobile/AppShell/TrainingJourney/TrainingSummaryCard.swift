import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingSummaryCard: View {
    let moduleCount: Int
    let quizScore: Int
    let quizTotal: Int
    let walletCount: Int
    let helpCount: Int
    let nextModuleTitle: String
    @Binding var selectedRating: Int
    let onSelectRating: (Int) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.l) {
                VStack(alignment: .leading, spacing: QAITokens.Spacing.xs) {
                    Text("Tamamlama ve Geri Bildirim")
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)

                    Text("Egitim tamamlandiginda sonuc, tekrar erisim yolu ve kisa geri bildirim ayni ekranda toplanmali.")
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    MetricChipView(title: "Modul", value: "\(moduleCount)", tint: QAITokens.Palette.chipBlue)
                    MetricChipView(
                        title: "Quiz",
                        value: "\(quizScore)/\(quizTotal)",
                        tint: quizScore == quizTotal ? QAITokens.Palette.chipTeal : QAITokens.Palette.chipAmber
                    )
                    MetricChipView(title: "Referans", value: "\(walletCount)", tint: QAITokens.Palette.cardElevated)
                }

                VStack(spacing: QAITokens.Spacing.s) {
                    SummaryLine(title: "Siradaki modul", value: nextModuleTitle)
                    SummaryLine(title: "Ipucu sayisi", value: "\(helpCount)")
                    SummaryLine(title: "Tekrar ac", value: "Ayarlar > Training Journey")
                    SummaryLine(title: "Erisilebilirlik", value: "Dynamic Type ve VoiceOver uyumlu")
                }

                RatingSelectorView(selectedRating: $selectedRating, onSelect: onSelectRating)
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: QAITokens.Spacing.m) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(nil)
            Spacer(minLength: 0)
        }
    }
}
