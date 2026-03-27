import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public struct MarketBridgeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @State private var selectedSection: BridgeSection = .snapshot

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: QAITokens.Spacing.l) {
                MarketBridgeHeroCard(
                    snapshot: env.marketBridge.snapshot,
                    selectedSymbol: env.settings.selectedSymbol,
                    usesSimulation: env.runtimeUsesSimulation,
                    isEnabled: env.settings.marketBridgeEnabled,
                    lastRefreshAt: env.marketBridge.lastRefreshAt,
                    lastError: env.marketBridge.lastError,
                    isLoading: env.marketBridge.isLoading,
                    refresh: refreshBridge,
                    openSite: openBridgeSite
                )

                BridgeSectionPicker(selectedSection: $selectedSection)

                switch selectedSection {
                case .snapshot:
                    CoinMarketSnapshotCard(snapshot: env.marketBridge.snapshot)
                    OperationsBridgeGuideCard()
                case .bridge:
                    CoinMarketCapBridgeConsoleCard(
                        snapshot: env.marketBridge.snapshot,
                        url: env.marketBridge.bridgeURL(for: env.settings.selectedSymbol),
                        isEnabled: env.settings.marketBridgeEnabled,
                        isLoading: env.marketBridge.isLoading,
                        lastError: env.marketBridge.lastError,
                        refresh: refreshBridge,
                        openSite: openBridgeSite
                    )
                case .guide:
                    TrainingDocumentCard(
                        htmlURL: TrainingBundleResource.trainingHTMLURL,
                        openBridge: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                selectedSection = .bridge
                            }
                        }
                    )
                    TrainingDocumentViewer()
                }
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .navigationTitle("Market Bridge")
        .qaiNavigationTitleDisplayMode(.inline)
        .task {
            env.training.loadIfNeeded()
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.selectedSymbol) { _, symbol in
            guard env.settings.marketBridgeEnabled, !symbol.isEmpty else { return }
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.marketBridgeEnabled) { _, isEnabled in
            _ = isEnabled
            env.applyRuntimeSettings()
        }
    }

    private func refreshBridge() {
        Task { await env.marketBridge.refreshNow() }
    }

    private func openBridgeSite() {
        openURL(env.marketBridge.bridgeURL(for: env.settings.selectedSymbol))
    }
}

private enum BridgeSection: String, CaseIterable, Identifiable {
    case snapshot
    case bridge
    case guide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snapshot:
            return "Snapshot"
        case .bridge:
            return "Köprü"
        case .guide:
            return "Rehber"
        }
    }

    var icon: String {
        switch self {
        case .snapshot:
            return "waveform.path.ecg"
        case .bridge:
            return "globe"
        case .guide:
            return "doc.richtext"
        }
    }
}

private struct MarketBridgeHeroCard: View {
    let snapshot: CoinMarketSnapshot?
    let selectedSymbol: String
    let usesSimulation: Bool
    let isEnabled: Bool
    let lastRefreshAt: Date?
    let lastError: String?
    let isLoading: Bool
    let refresh: () -> Void
    let openSite: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("CoinMarketCap Bridge")
                    .font(QAITokens.Typography.largeTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Canlı piyasa özetini CoinMarketCap köprüsü ile çek, seçili sembolü eğitim ve bot katmanına senkronize et.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: QAITokens.Spacing.xs) {
                        BridgeBadge(title: isEnabled ? "Köprü Açık" : "Köprü Kapalı", color: isEnabled ? QAITokens.Palette.teal : QAITokens.Palette.warning)
                        BridgeBadge(title: usesSimulation ? "Simülasyon" : "Canlı Operasyon", color: usesSimulation ? QAITokens.Palette.warning : QAITokens.Palette.gold)
                        BridgeBadge(title: selectedSymbol, color: QAITokens.Palette.cardElevated)
                        if let snapshot {
                            BridgeBadge(title: snapshot.assetName, color: QAITokens.Palette.chipBlue)
                            if let rank = snapshot.rank {
                                BridgeBadge(title: "Rank #\(rank)", color: QAITokens.Palette.chipAmber)
                            }
                        }
                    }
                }

                if let lastError, !lastError.isEmpty {
                    Text(lastError)
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.warning)
                } else if let snapshot {
                    Text("Son fiyat: \(currency(snapshot.priceUSD)) | Senkron: \(relativeText(lastRefreshAt ?? snapshot.updatedAt))")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                } else {
                    Text(isLoading ? "CoinMarketCap verisi çekiliyor..." : "İlk market snapshot bekleniyor.")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }

                HStack(spacing: 10) {
                    PrimaryActionButton(title: isLoading ? "Yenileniyor..." : "Yenile") {
                        refresh()
                    }
                        .disabled(isLoading || !isEnabled)

                    PrimaryActionButton(title: "Siteyi Aç", style: .secondary) {
                        openSite()
                    }
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }

    private func relativeText(_ date: Date?) -> String {
        guard let date else { return "henüz yok" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct CoinMarketSnapshotCard: View {
    let snapshot: CoinMarketSnapshot?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Label("Sistemsel Piyasa Verileri", systemImage: "chart.xyaxis.line")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                if let snapshot {
                    HStack(spacing: 10) {
                        SnapshotMetric(title: "Fiyat", value: money(snapshot.priceUSD), tint: QAITokens.Palette.chipAmber)
                        SnapshotMetric(title: "Rank", value: snapshot.rank.map { "#\($0)" } ?? "—", tint: QAITokens.Palette.chipBlue)
                    }

                    HStack(spacing: 10) {
                        SnapshotMetric(title: "Market Cap", value: compact(snapshot.marketCapUSD), tint: QAITokens.Palette.chipTeal)
                        SnapshotMetric(title: "24s Hacim", value: compact(snapshot.volume24hUSD), tint: QAITokens.Palette.chipAmber)
                    }

                    HStack(spacing: 10) {
                        SnapshotMetric(title: "FDV", value: compact(snapshot.fullyDilutedMarketCapUSD), tint: QAITokens.Palette.chipBlue)
                        SnapshotMetric(title: "Watchlist", value: snapshot.watchCount.map { "\($0)" } ?? "—", tint: QAITokens.Palette.cardElevated)
                    }

                    HStack(spacing: 10) {
                        SnapshotMetric(title: "Circulating", value: compact(snapshot.circulatingSupply), tint: QAITokens.Palette.cardElevated)
                        SnapshotMetric(title: "Max Supply", value: compact(snapshot.maxSupply), tint: QAITokens.Palette.cardElevated)
                    }
                } else {
                    Text("CoinMarketCap snapshot henüz hazır değil. Köprü aktif olduğunda seçili sembol için canlı özet burada görünecek.")
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }
            }
        }
    }

    private func money(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }

    private func compact(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch value {
        case 1_000_000_000...:
            return String(format: "$%.2fB", value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "$%.2fM", value / 1_000_000)
        case 1_000...:
            return String(format: "$%.2fK", value / 1_000)
        default:
            return String(format: "%.2f", value)
        }
    }
}

private struct OperationsBridgeGuideCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Operasyon Köprüsü", systemImage: "rectangle.3.group.bubble.left")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("CoinMarketCap köprüsü seçili sembolün canlı özetini getirir; botlar, eğitim presetleri ve lisanslı operasyon akışı aynı sembol üzerinde kalır.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    BridgeChecklistRow(text: "Dashboard ve Botlar ekranı artık aynı sembolü ortak kullanır.")
                    BridgeChecklistRow(text: "PDF rehber ve eğitim merkezi aynı operasyon menüsünden açılır.")
                    BridgeChecklistRow(text: "Alt menüler artık boş hedef yerine çalışan ekranlara bağlıdır.")
                }
            }
        }
    }
}

private struct TrainingDocumentCard: View {
    let htmlURL: URL?
    let openBridge: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Demo, Test ve HTML Rehber", systemImage: "doc.text.image")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Yüklediğin HTML kaynak kullanıcı odaklı yeni sürüm olarak uygulamaya entegre edildi. Bu merkez teknik servis süreçlerini değil, Demo ve Test adımlarını gösterir.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                HStack(spacing: 10) {
                    if let url = htmlURL {
                        Link(destination: url) {
                            Label("HTML Rehber", systemImage: "doc.viewfinder")
                                .font(QAITokens.Typography.bodyStrong)
                                .foregroundStyle(QAITokens.Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(QAITokens.Palette.cardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: QAITokens.Radius.button, style: .continuous))
                        }
                    }

                    PrimaryActionButton(title: "CMC Köprüsü") {
                        openBridge()
                    }
                }
            }
        }
    }
}

struct TrainingDocumentViewer: View {
    init() {}

    var body: some View {
        TrainingDemoCenterView()
    }
}

private struct BridgeSectionPicker: View {
    @Binding var selectedSection: BridgeSection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BridgeSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: section.icon)
                        Text(section.title)
                    }
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(selectedSection == section ? QAITokens.Palette.backgroundBottom : QAITokens.Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedSection == section ? QAITokens.Palette.gold : QAITokens.Palette.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SnapshotMetric: View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct BridgeBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(QAITokens.Typography.caption)
            .foregroundStyle(QAITokens.Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color)
            .clipShape(Capsule())
    }
}

private struct BridgeChecklistRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(QAITokens.Palette.teal)
            Text(text)
                .font(QAITokens.Typography.body)
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
    }
}

private struct CoinMarketCapBridgeConsoleCard: View {
    let snapshot: CoinMarketSnapshot?
    let url: URL
    let isEnabled: Bool
    let isLoading: Bool
    let lastError: String?
    let refresh: () -> Void
    let openSite: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("CoinMarketCap Native Bridge", systemImage: "globe.europe.africa.fill")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text("Gömülü web görünümü yerine canlı native snapshot kullanılır. CoinMarketCap sayfası dış tarayıcıda açılır ve uygulama içindeki veriler aynı sembolle senkron kalır.")
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    BridgeConsoleRow(label: "Durum", value: isEnabled ? (isLoading ? "Yenileniyor" : "Aktif") : "Kapalı")
                    BridgeConsoleRow(label: "Kaynak", value: url.absoluteString)
                    BridgeConsoleRow(label: "Varlık", value: snapshot?.assetName ?? "Snapshot bekleniyor")
                    BridgeConsoleRow(label: "Fiyat", value: snapshot.map { "$" + $0.priceUSD.formatted(.number.precision(.fractionLength(2))) } ?? "—")
                    if let lastError, !lastError.isEmpty {
                        BridgeConsoleRow(label: "Hata", value: lastError)
                    }
                }
                .padding(16)
                .background(QAITokens.Palette.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 10) {
                    PrimaryActionButton(title: isLoading ? "Yenileniyor..." : "Snapshot Yenile") {
                        refresh()
                    }
                        .disabled(!isEnabled || isLoading)

                    PrimaryActionButton(title: "CoinMarketCap Aç", style: .secondary) {
                        openSite()
                    }
                }
            }
        }
    }
}

private struct BridgeConsoleRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(QAITheme.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(QAITheme.textPrimary)
                .textSelection(.enabled)
        }
    }
}

#if canImport(PDFKit) && canImport(UIKit)
private struct PlatformPDFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor.clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
#elseif canImport(PDFKit) && canImport(AppKit)
private struct PlatformPDFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
#else
private struct PlatformPDFView: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label("PDF dosyasını dışarıda aç", systemImage: "doc")
                .foregroundStyle(QAITheme.accent)
        }
    }
}
#endif
