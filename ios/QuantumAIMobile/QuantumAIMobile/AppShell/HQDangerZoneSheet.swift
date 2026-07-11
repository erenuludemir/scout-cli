import SwiftUI

struct HQDangerZoneSheet: View {
    let request: HQDangerRequest
    let cancelAction: () -> Void
    let confirmAction: () -> Void

    @State private var acknowledged = false
    @State private var confirmationText = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: QAITokens.Spacing.l) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(request.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(request.message)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }

                    VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                        warningRow("Kritik operasyon akışı etkilenebilir.")
                        warningRow("Komut sonrası toast ve event kaydı üretilecek.")
                        warningRow("İşlem ikinci onay metni olmadan yürütülmez.")
                    }
                    .padding(QAITokens.Spacing.m)
                    .background(Color.red.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Toggle(isOn: $acknowledged) {
                        Text("Bu komutun etkisini anladım ve kontrollü şekilde yürütmek istiyorum.")
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                    }
                    .tint(QAITokens.Palette.gold)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Onay için `\(request.confirmPhrase)` yaz")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        TextField(request.confirmPhrase, text: $confirmationText)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(QAITokens.Palette.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    HStack(spacing: QAITokens.Spacing.s) {
                        button(title: "İptal", tint: QAITokens.Palette.cardElevated, foreground: QAITokens.Palette.textPrimary, action: cancelAction)
                        button(
                            title: "Komutu Yürüt",
                            tint: canConfirm ? Color.red.opacity(0.78) : QAITokens.Palette.cardElevated,
                            foreground: QAITokens.Palette.textPrimary
                        ) {
                            if canConfirm {
                                confirmAction()
                            }
                        }
                        .disabled(!canConfirm)
                    }
                }
                .padding(QAITokens.Layout.screenPadding)
                .padding(.vertical, QAITokens.Spacing.m)
            }
            .background(AppBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat", action: cancelAction)
                }
            }
        }
    }

    private var canConfirm: Bool {
        acknowledged && confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == request.confirmPhrase
    }

    private func warningRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(QAITokens.Palette.warning)
            Text(text)
                .font(QAITokens.Typography.body)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(nil)
        }
    }

    private func button(
        title: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
