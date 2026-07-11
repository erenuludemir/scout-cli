import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct WalletView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var address = "—"
    @State private var signResult = "Henüz yerel doğrulama çıktısı oluşturulmadı"
    @State private var statusMessage = "Referans yüzeyi hazırlanıyor"
    @State private var showsConnectorTools = false
    @State private var showsLivePrepConfirmation = false
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Ağ Referansı", showsBackButton: showsBackButton, onBack: { dismiss() })

                WalletHeroCard(
                    isLicensed: env.settings.isAuthenticated,
                    outboxDepth: env.storage.queueDepth(),
                    statusMessage: statusMessage,
                    totalEquityText: env.walletPortfolio.totalEquityText,
                    selectedNetworkName: selectedNetwork.name,
                    liveSource: env.walletPortfolio.dataSourceSummary
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Binance Spot Hazırlığı", systemImage: "checkmark.shield")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("Bu kart canlı feed, mikro test tutarı ve Binance geri dönüş doğrulamasını tek yerde hazırlar. Bu aksiyon emir göndermez; yalnızca canlı lane'i güvenli şekilde hazırlar.")
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            WalletSummaryTile(title: "Mod", value: liveModeLabel, tint: liveModeTint)
                            WalletSummaryTile(title: "Binance", value: binanceVerificationLabel, tint: binanceVerificationTint)
                            WalletSummaryTile(title: "Feed", value: liveFeedLabel, tint: liveFeedTint)
                            WalletSummaryTile(title: "Mikro Test", value: "$\(Int(env.settings.dcaAmount.rounded()))", tint: microTestTint)
                        }

                        Text(livePreparationStatus)
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)

                        HStack(spacing: 10) {
                            WalletActionButton(title: "Canlı Spot Hazırla", tint: QAITheme.success) {
                                showsLivePrepConfirmation = true
                            }
                            WalletActionButton(title: "Güvenli Sim", tint: QAITheme.surfaceMuted, usesDarkForeground: false) {
                                Task { await returnToSafeSimulation() }
                            }
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsConnectorTools = true
                            }
                            statusMessage = "Binance doğrulama paneli açıldı. Harici uygulama dönüşü burada yerel olarak tamamlanır."
                        } label: {
                            Text("Binance Doğrulama Panelini Aç")
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(QAITheme.panelBlue.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Referans Adres", systemImage: "doc.text.magnifyingglass")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(address)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            WalletActionButton(title: "Adresi Yenile", tint: QAITheme.accent) {
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
                        Label("Ağ Özeti", systemImage: "waveform.path.ecg.rectangle")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            WalletSummaryTile(
                                title: "Native",
                                value: WalletPortfolioService.assetString(selectedSnapshot?.balance, symbol: selectedNetwork.symbol),
                                tint: QAITheme.panelBlue
                            )
                            WalletSummaryTile(
                                title: "USD",
                                value: WalletPortfolioService.usdString(selectedSnapshot?.valueUSD),
                                tint: QAITheme.accent
                            )
                            WalletSummaryTile(
                                title: "Kaynak",
                                value: selectedSnapshot?.origin.rawValue ?? env.walletPortfolio.dataSourceSummary,
                                tint: QAITheme.success
                            )
                        }

                        Text(balanceSupportText)
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Yerel İmza Provası", systemImage: "signature")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(signResult)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            WalletActionButton(title: "İmzayı Üret", tint: QAITheme.accent) {
                                signMessage()
                            }
                            WalletActionButton(title: "Yerelde Doğrula", tint: QAITheme.success) {
                                Task { await performSecureTransaction() }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Yerel Durum", systemImage: "tray.full.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        HStack(spacing: 10) {
                            WalletSummaryTile(
                                title: "Kayıt",
                                value: "\(env.storage.queueDepth())",
                                tint: QAITheme.warning
                            )
                            WalletSummaryTile(
                                title: "Ağ",
                                value: selectedNetwork.name,
                                tint: QAITheme.panelBlue
                            )
                            WalletSummaryTile(
                                title: "Erişim",
                                value: env.settings.isAuthenticated ? "Açık" : "Temel",
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

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Harici Referans Bağlantıları", systemImage: "link.badge.plus")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("Bu alan varsayılan olarak kapalı tutulur. Yalnızca geri dönüş ve yerel doğrulama akışını kontrol etmek gerektiğinde açılır.")
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showsConnectorTools.toggle()
                            }
                        } label: {
                            Text(showsConnectorTools ? "Bağlantıları Gizle" : "Bağlantıları Göster")
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(QAITheme.surfaceMuted.opacity(0.24))
                                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        if showsConnectorTools {
                            WalletActivationPanel()
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Desteklenen Ağlar", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("\(supportedNetworks.count) ağ için adres çözümleme ve yerel imza provası hazır. Açık harici bağlantı sayısı: \(env.walletActivation.verifiedProviders.count).")
                            .font(.subheadline)
                            .foregroundStyle(QAITokens.Palette.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(supportedNetworks) { network in
                                    Button {
                                        env.settings.selectedWalletNetworkID = network.id
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(network.name)
                                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            Text(network.family.title + " • " + network.symbol)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(env.settings.selectedWalletNetworkID == network.id ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(env.settings.selectedWalletNetworkID == network.id ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
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
        .confirmationDialog(
            "Canlı Spot Hazırlığı",
            isPresented: $showsLivePrepConfirmation,
            titleVisibility: .visible
        ) {
            Button("Canlı Spot Hazırlığını Uygula") {
                Task { await armLiveBinanceSpot() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu adım gerçek emir göndermez. Paper Trading kapanır, canlı adapter hattı açılır ve mikro test tutarı 3$ ile 5$ aralığında sınırlandırılır.")
        }
        .task {
            env.settings.selectedWalletNetworkID = selectedNetwork.id
            await refreshWalletData()
            showAddress()
        }
        .onChange(of: env.settings.selectedWalletNetworkID) { _, _ in
            Task {
                await refreshWalletData()
                showAddress()
            }
        }
    }

    private func showAddress() {
        do {
            if let resolvedAddress = env.walletPortfolio.resolvedAddress(for: selectedNetwork.id) {
                address = resolvedAddress
            } else {
                address = try env.wallet.address(for: selectedNetwork)
            }
            if let selectedSnapshot, selectedSnapshot.isLive {
                statusMessage = "\(selectedNetwork.name) referans özeti yenilendi"
            } else {
                statusMessage = "\(selectedNetwork.name) adresi yerel olarak hazırlandı"
            }
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func signMessage() {
        do {
            signResult = try env.wallet.sign(Data("hello".utf8)).base64EncodedString()
            statusMessage = "\(selectedNetwork.name) için yerel imza provası üretildi"
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func copyAddress() {
        guard address != "—" else {
            statusMessage = "Önce \(selectedNetwork.name) adresini hazırlayın"
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = address
        #endif
        statusMessage = "\(selectedNetwork.name) referans adresi panoya kopyalandı"
    }

    private func performSecureTransaction() async {
        do {
            statusMessage = "\(selectedNetwork.name) için yerel doğrulama bekleniyor..."
            try await SecurityGate.verifyAction(reason: "Yerel doğrulamayı tamamlamak için Face ID / Touch ID kullanın.")
            statusMessage = "\(selectedNetwork.name) için prova imzası hazırlanıyor..."
            let signature = try signatureForSelectedNetwork()
            signResult = signature.base64EncodedString()
            statusMessage = "\(selectedNetwork.name) için yerel doğrulama tamamlandı. Yayın veya transfer yapılmadı."
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    private func armLiveBinanceSpot() async {
        env.settings.isAuthenticated = true
        env.settings.isPaperTrading = false
        env.settings.liveAdapters = true
        env.settings.marketBridgeEnabled = true
        env.settings.telemetryEnabled = true
        env.settings.dcaAmount = max(3, min(env.settings.dcaAmount, 5))
        env.settings.copyRatio = min(env.settings.copyRatio, 0.10)
        env.applyRuntimeSettings()

        withAnimation(.easeInOut(duration: 0.2)) {
            showsConnectorTools = true
        }

        await refreshWalletData()
        showAddress()
        statusMessage = "Canlı spot hazırlığı uygulandı. Emir gönderilmedi; mikro test limiti $\(Int(env.settings.dcaAmount.rounded())) ve Binance doğrulaması bekleniyor."
    }

    private func returnToSafeSimulation() async {
        env.settings.isPaperTrading = true
        env.settings.liveAdapters = false
        env.settings.marketBridgeEnabled = false
        env.applyRuntimeSettings()

        await refreshWalletData()
        showAddress()
        statusMessage = "Güvenli simülasyon hattına dönüldü. Canlı emir yolu kapatıldı."
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
        WalletChainRegistry.network(id: env.settings.selectedWalletNetworkID) ?? WalletChainRegistry.defaultNetwork
    }

    private var selectedSnapshot: WalletNetworkBalance? {
        env.walletPortfolio.selectedSnapshot
    }

    private var balanceSupportText: String {
        if let selectedSnapshot {
            if let error = selectedSnapshot.error {
                return selectedSnapshot.addressOrigin.rawValue + " adres çözüldü fakat canlı özet alınamadı: " + error
            }
            let refreshText = env.walletPortfolio.lastRefreshDescription
            return selectedSnapshot.addressOrigin.rawValue + " adres referans olarak kullanılıyor. Son yenileme: " + refreshText + "."
        }
        return "Ağ özeti yükleniyor. Ağ seçimi değiştiğinde doğru adres ve özet tekrar çözülür."
    }

    private var liveModeLabel: String {
        env.runtimeUsesSimulation ? "Simülasyon" : "Canlı lane"
    }

    private var liveModeTint: Color {
        env.runtimeUsesSimulation ? QAITheme.warning : QAITheme.success
    }

    private var binanceVerificationStatus: WalletConnectorStatus {
        env.walletActivation.status(for: .binance)
    }

    private var binanceVerificationLabel: String {
        switch binanceVerificationStatus {
        case .idle:
            return "Bekleniyor"
        case .activationStarted:
            return "Geri dönüş bekliyor"
        case .verified:
            return "Yerelde onaylı"
        }
    }

    private var binanceVerificationTint: Color {
        switch binanceVerificationStatus {
        case .idle:
            return QAITheme.warning
        case .activationStarted:
            return QAITheme.accent
        case .verified:
            return QAITheme.success
        }
    }

    private var liveFeedLabel: String {
        if env.runtimeUsesSimulation {
            return "Simüle tick"
        }
        if env.market.last != nil {
            return "Canlı tick"
        }
        return "Tick bekleniyor"
    }

    private var liveFeedTint: Color {
        if env.runtimeUsesSimulation {
            return QAITheme.warning
        }
        return env.market.last != nil ? QAITheme.success : QAITheme.panelBlue
    }

    private var microTestTint: Color {
        env.settings.dcaAmount <= 5 ? QAITheme.success : QAITheme.warning
    }

    private var livePreparationIssues: [String] {
        var issues: [String] = []
        if env.runtimeUsesSimulation {
            issues.append("Paper Trading hâlâ açık.")
        }
        if !env.settings.marketBridgeEnabled {
            issues.append("Market Bridge kapalı.")
        }
        if !env.settings.telemetryEnabled {
            issues.append("Telemetri kapalı.")
        }
        if binanceVerificationStatus != .verified {
            issues.append("Binance yerel doğrulaması tamamlanmadı.")
        }
        if !env.runtimeUsesSimulation && env.market.last == nil {
            issues.append("İlk canlı tick henüz gelmedi.")
        }
        if env.settings.dcaAmount > 5 {
            issues.append("DCA mikro test limiti 5 USD üstünde.")
        }
        return issues
    }

    private var livePreparationStatus: String {
        if livePreparationIssues.isEmpty {
            return "Canlı spot doğrulama hattı hazır. Binance Spot içinde manuel 3–5 USD denemeyi yaptıktan sonra uygulamaya geri dönüp feed ve cüzdan özetini kontrol edebilirsiniz."
        }
        return "Hazırlıkta kalan maddeler: " + livePreparationIssues.joined(separator: " • ")
    }

    private func refreshWalletData() async {
        env.walletPortfolio.reconfigure(
            selectedNetworkID: selectedNetwork.id,
            walletService: env.wallet,
            networks: supportedNetworks
        )
        await env.walletPortfolio.refreshNow()
    }
}

private struct WalletHeroCard: View {
    let isLicensed: Bool
    let outboxDepth: Int
    let statusMessage: String
    let totalEquityText: String
    let selectedNetworkName: String
    let liveSource: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QuantumAI Reference")
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                        Text(statusMessage)
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    Spacer()

                    AppMarkView(size: 42)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    WalletSummaryTile(title: "Durum", value: isLicensed ? "Hazır" : "Temel", tint: isLicensed ? QAITokens.Palette.teal : QAITokens.Palette.warning)
                    WalletSummaryTile(title: "Özet", value: totalEquityText, tint: QAITokens.Palette.chipBlue)
                    WalletSummaryTile(title: "Ağ", value: selectedNetworkName, tint: QAITokens.Palette.cardElevated)
                    WalletSummaryTile(title: "Kayıt", value: "\(outboxDepth)", tint: QAITokens.Palette.gold)
                }

                Text("Live source: " + liveSource + " • yayın yok")
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
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
