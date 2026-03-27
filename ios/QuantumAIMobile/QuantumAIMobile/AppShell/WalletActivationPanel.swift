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
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label(headline, systemImage: "link.badge.plus")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text(subtitle)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                HStack(spacing: QAITokens.Spacing.s) {
                    ActivationSummaryTile(
                        title: "Doğrulanan",
                        value: "\(env.walletActivation.verifiedProviders.count)/\(WalletConnectorProvider.allCases.count)",
                        tint: QAITokens.Palette.teal
                    )
                    ActivationSummaryTile(
                        title: "Güvenlik",
                        value: "Face ID / Parola",
                        tint: QAITokens.Palette.gold
                    )
                }

                Text(statusMessage)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

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
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Text(provider.summary)
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }

                Spacer()

                Text(statusLabel)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(statusColor.opacity(0.16))
                    .clipShape(Capsule())
            }

            if let verifiedAt, status == .verified {
                Text("Son doğrulama: \(verifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }

            HStack(spacing: QAITokens.Spacing.s) {
                ActivationButton(
                    title: "Aktive Et",
                    tint: QAITokens.Palette.chipBlue,
                    action: onActivate
                )
                ActivationButton(
                    title: status == .verified ? "Doğrulandı" : "Doğrula",
                    tint: QAITokens.Palette.teal,
                    action: onVerify
                )
                .disabled(status == .idle || status == .verified)
                .opacity(status == .idle ? 0.45 : 1)
            }

            if status != .idle {
                Button(action: onReset) {
                    Text("Sıfırla")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            return QAITokens.Palette.warning
        case .activationStarted:
            return QAITokens.Palette.gold
        case .verified:
            return QAITokens.Palette.teal
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
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(tint.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
