import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct WalletActivationPanel: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    let headline: String
    let subtitle: String
    let onVerified: ((WalletConnectorProvider) -> Void)?

    @State private var statusMessage = "Aktivasyon sonrası doğrulama burada tamamlanır ve işlem akışı uygulama içinde sürer."

    public init(
        headline: String = "Harici Wallet Aktivasyonu",
        subtitle: String = "Binance, Coinbase Wallet, Trust Wallet ve MetaMask için aktivasyon, doğrulama ve geri dönüş akışını tek yerden yönet.",
        onVerified: ((WalletConnectorProvider) -> Void)? = nil
    ) {
        self.headline = headline
        self.subtitle = subtitle
        self.onVerified = onVerified
    }

    public var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                Label(headline, systemImage: "link.badge.plus")
                    .font(QAITheme.sectionTitleFont)
                    .foregroundStyle(QAITheme.textPrimary)

                Text(subtitle)
                    .font(QAITheme.bodyFont)
                    .foregroundStyle(QAITheme.textSecondary)

                HStack(spacing: 10) {
                    ActivationSummaryTile(
                        title: "Doğrulanan",
                        value: "\(env.walletActivation.verifiedProviders.count)/\(WalletConnectorProvider.allCases.count)",
                        tint: QAITheme.success
                    )
                    ActivationSummaryTile(
                        title: "Güvenlik",
                        value: "Face ID / Parola",
                        tint: QAITheme.accent
                    )
                }

                Text(statusMessage)
                    .font(QAITheme.bodyFont)
                    .foregroundStyle(QAITheme.textSecondary)

                ForEach(WalletConnectorProvider.allCases) { provider in
                    WalletConnectorRow(
                        provider: provider,
                        status: env.walletActivation.status(for: provider),
                        verifiedAt: env.walletActivation.verifiedAt(for: provider),
                        onActivate: { activate(provider) },
                        onVerify: { Task { await verify(provider) } },
                        onReset: { reset(provider) }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let provider = pendingVerificationProvider else { return }
            statusMessage = "\(provider.title) aktivasyonundan QuantumAI'ya geri dönüldü. Doğrulamayı burada tamamlayıp akışa devam et."
        }
    }

    private func activate(_ provider: WalletConnectorProvider) {
        env.walletActivation.markActivationStarted(for: provider)
        openURL(provider.activationURL)
        statusMessage = "\(provider.title) açıldı. Dış doğrulamayı bitirip uygulamaya geri dön, işlem burada devam etsin."
    }

    private func verify(_ provider: WalletConnectorProvider) async {
        do {
            statusMessage = "\(provider.title) için Face ID / cihaz parolası doğrulaması bekleniyor..."
            try await SecurityGate.verifyAction(
                reason: "\(provider.title) entegrasyonunu doğrulamak için Face ID, Touch ID veya cihaz parolasını kullanın."
            )
            env.walletActivation.markVerified(for: provider)
            onVerified?(provider)
            statusMessage = "\(provider.title) doğrulandı. Sonraki imza ve işlem akışı artık uygulama içinden devam edecek."
        } catch {
            statusMessage = "Doğrulama tamamlanmadı: \(error.localizedDescription)"
        }
    }

    private func reset(_ provider: WalletConnectorProvider) {
        env.walletActivation.reset(provider)
        statusMessage = "\(provider.title) aktivasyon durumu sıfırlandı."
    }

    private var pendingVerificationProvider: WalletConnectorProvider? {
        WalletConnectorProvider.allCases.first { env.walletActivation.status(for: $0) == .activationStarted }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct WalletConnectorRow: View {
    let provider: WalletConnectorProvider
    let status: WalletConnectorStatus
    let verifiedAt: Date?
    let onActivate: () -> Void
    let onVerify: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.title)
                        .font(QAITheme.sectionTitleFont)
                        .foregroundStyle(QAITheme.textPrimary)
                    Text(provider.summary)
                        .font(QAITheme.bodyFont)
                        .foregroundStyle(QAITheme.textSecondary)
                }

                Spacer()

                Text(statusLabel)
                    .font(QAITheme.captionFont.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, QAITheme.compactChipHorizontalPadding)
                    .padding(.vertical, QAITheme.compactChipVerticalPadding)
                    .background(statusColor.opacity(0.16))
                    .clipShape(Capsule())
            }

            if let verifiedAt, status == .verified {
                Text("Son doğrulama: \(verifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(QAITheme.captionFont)
                    .foregroundStyle(QAITheme.textSecondary)
            }

            HStack(spacing: 10) {
                ActivationButton(
                    title: "Aktive Et",
                    tint: QAITheme.panelBlue,
                    action: onActivate
                )
                ActivationButton(
                    title: status == .verified ? "Doğrulandı" : "Doğrula",
                    tint: QAITheme.success,
                    action: onVerify
                )
                .disabled(status == .idle || status == .verified)
                .opacity(status == .idle ? 0.45 : 1)
            }

            if status != .idle {
                Button(action: onReset) {
                    Text("Sıfırla")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QAITheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(QAITheme.surfaceMuted.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }

    private var statusLabel: String {
        switch status {
        case .idle:
            return "Bekliyor"
        case .activationStarted:
            return "Aktivasyon Açıldı"
        case .verified:
            return "Doğrulandı"
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle:
            return QAITheme.warning
        case .activationStarted:
            return QAITheme.accent
        case .verified:
            return QAITheme.success
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ActivationSummaryTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QAITheme.captionFont)
                .foregroundStyle(QAITheme.textSecondary)
            Text(value)
                .font(QAITheme.metricFont)
                .foregroundStyle(QAITheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ActivationButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QAITheme.buttonFont)
                .foregroundStyle(QAITheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(tint.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
