import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct WalletView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var address = "—"
    @State private var signResult = "Henüz imza oluşturulmadı"
    @State private var statusMessage = "Cüzdan hazırlanıyor"
    @State private var selectedNetworkID = WalletChainRegistry.defaultNetwork.id
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Cüzdan", showsBackButton: showsBackButton, onBack: { dismiss() })

                WalletHeroCard(
                    isLicensed: env.settings.isAuthenticated,
                    outboxDepth: env.storage.queueDepth(),
                    statusMessage: statusMessage
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Ana Adres", systemImage: "wallet.pass.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(address)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            WalletActionButton(title: "Adresi Göster", tint: QAITheme.accent) {
                                showAddress()
                            }
                            WalletActionButton(title: "Kopyala", tint: QAITheme.surfaceMuted, usesDarkForeground: false) {
                                copyAddress()
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("İmza ve Güvenlik", systemImage: "signature")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(signResult)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            WalletActionButton(title: "Test İmzala", tint: QAITheme.accent) {
                                signMessage()
                            }
                            WalletActionButton(title: "Güvenli Gönder", tint: QAITheme.success) {
                                Task { await performSecureTransaction() }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Operasyon Özeti", systemImage: "tray.full.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        HStack(spacing: 10) {
                            WalletSummaryTile(
                                title: "Bekleyen",
                                value: "\(env.storage.queueDepth())",
                                tint: QAITheme.warning
                            )
                            WalletSummaryTile(
                                title: "Ağ",
                                value: selectedNetwork.name,
                                tint: QAITheme.panelBlue
                            )
                            WalletSummaryTile(
                                title: "Lisans",
                                value: env.settings.isAuthenticated ? "Aktif" : "Demo",
                                tint: env.settings.isAuthenticated ? QAITheme.success : QAITheme.surfaceMuted
                            )
                        }

                        HStack(spacing: 10) {
                            NavigationLink {
                                MarketBridgeView(showsBackButton: true)
                            } label: {
                                WalletLinkTile(title: "Market Bridge", tint: QAITheme.panelBlue)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                TrainingDocumentViewer()
                            } label: {
                                WalletLinkTile(title: "Test & Demo", tint: QAITheme.surfaceMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                WalletActivationPanel(
                    headline: "Wallet Aktivasyonu ve Doğrulama",
                    subtitle: "Binance, Coinbase Wallet, Trust Wallet ve MetaMask doğrulamasını bitir; ardından imza ve işlem akışı bu uygulamada devam etsin."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Blockchain Ağları", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("\(supportedNetworks.count) ağ entegre edildi. Seçilen ağ üzerinden wallet akışı ve güvenli imza tetiklenir. Doğrulanan harici wallet sayısı: \(env.walletActivation.verifiedProviders.count).")
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(supportedNetworks) { network in
                                    Button {
                                        selectedNetworkID = network.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(network.name)
                                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            Text(network.family.title + " • " + network.symbol)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(selectedNetworkID == network.id ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(selectedNetworkID == network.id ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .task {
            showAddress()
        }
    }

    private func showAddress() {
        do {
            address = try env.wallet.address()
            statusMessage = "Cüzdan hazır"
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func signMessage() {
        do {
            signResult = try env.wallet.sign(Data("hello".utf8)).base64EncodedString()
            statusMessage = "İmza üretildi"
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func copyAddress() {
        guard address != "—" else {
            statusMessage = "Önce adresi üretin"
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = address
        #endif
        statusMessage = "Adres panoya kopyalandı"
    }

    private func performSecureTransaction() async {
        do {
            statusMessage = "\(selectedNetwork.name) için biyometrik doğrulama bekleniyor..."
            try await SecurityGate.verifyAction(reason: "İşlemi onaylamak için Face ID / Touch ID kullanın.")
            statusMessage = "\(selectedNetwork.name) işlemi imzalanıyor..."
            let signature = try signatureForSelectedNetwork()
            statusMessage = "\(selectedNetwork.name) işlemi outbox kuyruğuna alınıyor..."
            let price = env.market.last?.price ?? Double(signature.count)
            let order = Order(
                id: String(UUID().uuidString.prefix(8).lowercased()),
                symbol: selectedNetwork.symbol + "USDT",
                side: "SIGN",
                price: price,
                amount: 0.1,
                timestamp: .now
            )
            env.storage.queueForBroadcast(order)
            signResult = signature.base64EncodedString()
            statusMessage = "\(selectedNetwork.name) güvenli gönderim kuyruğa alındı"
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func signatureForSelectedNetwork() throws -> Data {
        let payload = Data("secure_tx:\(selectedNetwork.id)".utf8)
        switch selectedNetwork.family {
        case .evm:
            return try env.wallet.signEVM(
                tx: RawTransaction(
                    chainId: selectedNetwork.chainID ?? 1,
                    nonce: 0,
                    to: "0x0000000000000000000000000000000000000000",
                    value: 0,
                    data: payload
                )
            )
        case .tron:
            return try env.wallet.signTRON(txHash: payload)
        case .solana:
            return try env.wallet.signSolana(message: payload)
        case .bitcoin:
            return try env.wallet.signBitcoin(transaction: payload)
        }
    }

    private var supportedNetworks: [WalletNetwork] {
        env.wallet.supportedNetworks()
    }

    private var selectedNetwork: WalletNetwork {
        WalletChainRegistry.network(id: selectedNetworkID) ?? WalletChainRegistry.defaultNetwork
    }
}

private struct WalletHeroCard: View {
    let isLicensed: Bool
    let outboxDepth: Int
    let statusMessage: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QuantumAI Vault")
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(statusMessage)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    Spacer()

                    AppMarkView(size: 42)
                }

                HStack(spacing: 10) {
                    WalletSummaryTile(title: "Durum", value: isLicensed ? "Premium" : "Demo", tint: isLicensed ? QAITokens.Palette.teal : QAITokens.Palette.warning)
                    WalletSummaryTile(title: "Outbox", value: "\(outboxDepth)", tint: QAITokens.Palette.gold)
                }
            }
        }
    }
}

private struct WalletActionButton: View {
    let title: String
    let tint: Color
    let usesDarkForeground: Bool
    let action: () -> Void

    init(title: String, tint: Color, usesDarkForeground: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.usesDarkForeground = usesDarkForeground
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QAITokens.Typography.bodyStrong)
                .foregroundStyle(usesDarkForeground ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WalletSummaryTile: View {
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
        .background(tint.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct WalletLinkTile: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(QAITokens.Typography.bodyStrong)
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(tint.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
    }
}
