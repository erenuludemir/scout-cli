import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showInvoice = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Ayarlar")

                SettingsHeroCard(
                    effectiveMode: env.runtimeUsesSimulation ? "Simülasyon" : "Canlı",
                    licenseText: env.settings.isAuthenticated ? "Enterprise" : "Ücretsiz",
                    activationDate: env.settings.licenseActivatedAt
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Operasyon Modu", icon: "switch.2")
                        SettingsToggleRow(
                            title: "Paper Trading",
                            subtitle: "Siparişleri simüle eder, gerçek adapter yerine iç feed kullanır.",
                            isOn: $env.settings.isPaperTrading
                        )
                        SettingsToggleRow(
                            title: "Live Adapters",
                            subtitle: "Açıkken canlı market akışı kullanılır. Kapalıysa güvenli sim moduna düşer.",
                            isOn: $env.settings.liveAdapters
                        )
                        SettingsToggleRow(
                            title: "Telemetri",
                            subtitle: "Order latency, retry ve operasyon verilerini yerel olarak kaydeder.",
                            isOn: $env.settings.telemetryEnabled
                        )
                        SettingsToggleRow(
                            title: "CoinMarketCap Bridge",
                            subtitle: "Seçili sembol için CoinMarketCap snapshot köprüsünü ve dış bağlantı akışını aktif eder.",
                            isOn: $env.settings.marketBridgeEnabled
                        )

                        StatusStrip(
                            label: "Aktif Çalışma Modu",
                            value: env.runtimeUsesSimulation ? "Simüle Feed" : "Canlı Feed",
                            color: env.runtimeUsesSimulation ? QAITheme.warning : QAITheme.success
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Alt Menüler", icon: "square.grid.2x2")
                        NavigationLink {
                            StrategyPreferencesView()
                        } label: {
                            SettingsMenuRow(
                                title: "Strateji Parametreleri",
                                subtitle: "DCA, Grid, CopyTrade ve şok eşiği"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MarketPreferencesView()
                        } label: {
                            SettingsMenuRow(
                                title: "Piyasa ve İzleme",
                                subtitle: "Sembol seçimi ve çalışma kanalı"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MarketBridgeView(showsBackButton: true)
                        } label: {
                            SettingsMenuRow(
                                title: "Market Bridge",
                                subtitle: "CoinMarketCap köprüsü, canlı özet ve native bridge paneli"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            LicenseCenterView(onPurchase: { showInvoice = true })
                        } label: {
                            SettingsMenuRow(
                                title: "Lisans Merkezi",
                                subtitle: env.settings.isAuthenticated ? "Aktif abonelik ve erişim seviyesi" : "TRC20 ile aktivasyon"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            IntelligenceCenterView()
                        } label: {
                            SettingsMenuRow(
                                title: "Beyin Merkezi",
                                subtitle: "8590 satırlık eğitim kaynağından türeyen bilgi merkezi"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            StrategyLibraryView()
                        } label: {
                            SettingsMenuRow(
                                title: "Strateji Kütüphanesi",
                                subtitle: "Hazır presetler ve uygulama akışları"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TrainingJourneyView()
                        } label: {
                            SettingsMenuRow(
                                title: "Training Journey",
                                subtitle: "Welcome, sandbox, quiz ve kaldığın yerden devam"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            RunbookCenterView()
                        } label: {
                            SettingsMenuRow(
                                title: "Runbook",
                                subtitle: "Operasyon, güvenlik ve API prosedürleri"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TrainingDocumentViewer()
                        } label: {
                            SettingsMenuRow(
                                title: "Test ve Demo Merkezi",
                                subtitle: "HTML rehber, demo akışı ve test adımları"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Lisans Durumu", icon: "crown.fill")
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: env.settings.isAuthenticated ? "checkmark.seal.fill" : "crown.fill")
                                .font(.title2)
                                .foregroundStyle(env.settings.isAuthenticated ? QAITheme.success : QAITheme.accent)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(env.settings.isAuthenticated ? "Enterprise Lisans Aktif" : "Ücretsiz Sürüm")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(QAITheme.textPrimary)
                                Text(env.settings.isAuthenticated ? "Bot, panel ve cüzdan özellikleri tam erişimde." : "Aktivasyon sonrası premium bot akışları kalıcı olarak açılır.")
                                    .font(.subheadline)
                                    .foregroundStyle(QAITheme.textSecondary)

                                if let date = env.settings.licenseActivatedAt, env.settings.isAuthenticated {
                                    Text("Aktivasyon: \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(QAITheme.textSecondary)
                                }
                            }

                            Spacer()
                        }

                        if env.settings.isAuthenticated {
                            StatusStrip(label: "Erişim", value: "Premium mod aktif", color: QAITheme.success)
                        } else {
                            PrimaryActionButton(title: "Lisans Satin Al (USDT)") {
                                showInvoice = true
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
        .sheet(isPresented: $showInvoice) {
            NavigationStack {
                SaaSInvoiceView()
                    .toolbar {
                        ToolbarItem(placement: closeToolbarPlacement) {
                            Button("Kapat") { showInvoice = false }
                        }
                    }
            }
        }
        .onChange(of: env.settings.isPaperTrading) { _, _ in
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.liveAdapters) { _, _ in
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.selectedSymbol) { _, _ in
            env.applyRuntimeSettings()
        }
        .onChange(of: env.settings.marketBridgeEnabled) { _, _ in
            env.applyRuntimeSettings()
        }
    }
}

private struct StrategyPreferencesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ScreenHeader(title: "Strateji Parametreleri", showsBackButton: true, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("DCA Motoru", icon: "waveform.path.badge.plus")
                        SliderControl(
                            title: "Tutar",
                            valueText: "$\(Int(env.settings.dcaAmount))",
                            value: Binding(
                                get: { env.settings.dcaAmount },
                                set: { env.settings.dcaAmount = $0.rounded(.toNearestOrAwayFromZero) }
                            ),
                            range: 10...250
                        )
                        StepperRow(title: "Periyot", valueText: "\(env.settings.dcaPeriodSec) sn") {
                            env.settings.dcaPeriodSec = max(5, env.settings.dcaPeriodSec - 5)
                        } onIncrement: {
                            env.settings.dcaPeriodSec += 5
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Grid Bandı", icon: "square.grid.3x3.fill")
                        StepperRow(title: "Alt Bant", valueText: "$\(Int(env.settings.gridLower))") {
                            env.settings.gridLower = max(1_000, env.settings.gridLower - 250)
                        } onIncrement: {
                            env.settings.gridLower += 250
                        }
                        StepperRow(title: "Üst Bant", valueText: "$\(Int(env.settings.gridUpper))") {
                            env.settings.gridUpper = max(env.settings.gridLower + 500, env.settings.gridUpper - 250)
                        } onIncrement: {
                            env.settings.gridUpper += 250
                        }
                        StepperRow(title: "Kademe", valueText: "\(env.settings.gridSteps)") {
                            env.settings.gridSteps = max(2, env.settings.gridSteps - 1)
                        } onIncrement: {
                            env.settings.gridSteps += 1
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Copy & Risk", icon: "shield.lefthalf.filled")
                        SliderControl(
                            title: "CopyTrade Oranı",
                            valueText: String(format: "%.2fx", env.settings.copyRatio),
                            value: $env.settings.copyRatio,
                            range: 0.25...3.0
                        )
                        SliderControl(
                            title: "Şok Eşiği",
                            valueText: String(format: "%.2f%%", env.settings.shockThreshold * 100),
                            value: $env.settings.shockThreshold,
                            range: 0.005...0.05
                        )
                    }
                }
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }
}

private struct MarketPreferencesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    private let symbols = ["BTCUSDT", "ETHUSDT", "BNBUSDT", "SOLUSDT"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ScreenHeader(title: "Piyasa ve Izleme", showsBackButton: true, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Ana Sembol", icon: "chart.line.uptrend.xyaxis")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(symbols, id: \.self) { symbol in
                                Button {
                                    env.settings.selectedSymbol = symbol
                                } label: {
                                    Text(symbol)
                                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                        .foregroundStyle(env.settings.selectedSymbol == symbol ? QAITheme.background : QAITheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(env.settings.selectedSymbol == symbol ? QAITheme.accent : QAITheme.surfaceMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Çalışma Kanalı", icon: "antenna.radiowaves.left.and.right")
                        StatusStrip(
                            label: "Aktif Feed",
                            value: env.runtimeUsesSimulation ? "Simülasyon / Güvenli" : "Canlı Adapter",
                            color: env.runtimeUsesSimulation ? QAITheme.warning : QAITheme.success
                        )
                        StatusStrip(
                            label: "CMC Köprüsü",
                            value: env.settings.marketBridgeEnabled ? "Aktif" : "Kapalı",
                            color: env.settings.marketBridgeEnabled ? QAITheme.panelBlue : QAITheme.surfaceMuted
                        )
                        Text("Sembol değişikliği ve canlı/sim mod geçişleri anında market akışını yeniden başlatır.")
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)

                        NavigationLink {
                            MarketBridgeView(showsBackButton: true)
                        } label: {
                            SettingsMenuRow(
                                title: "CoinMarketCap Köprüsünü Aç",
                                subtitle: "Seçili sembol için canlı piyasa özetini görüntüle"
                            )
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
    }
}

private struct LicenseCenterView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let onPurchase: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ScreenHeader(title: "Lisans Merkezi", showsBackButton: true, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Lisans Merkezi", icon: "checkmark.shield.fill")
                        StatusStrip(
                            label: "Durum",
                            value: env.settings.isAuthenticated ? "Aktif" : "Pasif",
                            color: env.settings.isAuthenticated ? QAITheme.success : QAITheme.warning
                        )

                        if let date = env.settings.licenseActivatedAt, env.settings.isAuthenticated {
                            Text("Bu cihazda lisans kalıcı olarak saklandı. Aktivasyon zamanı: \(date.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.subheadline)
                                .foregroundStyle(QAITheme.textSecondary)
                        } else {
                            Text("TRC20 ödeme doğrulaması tamamlandığında lisans durumu otomatik kaydedilir ve tüm menüler premium modda açılır.")
                                .font(.subheadline)
                                .foregroundStyle(QAITheme.textSecondary)
                        }

                        if !env.settings.isAuthenticated {
                            PrimaryActionButton(title: "USDT ile Aktivasyon") {
                                onPurchase()
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
    }
}

private struct SettingsHeroCard: View {
    let effectiveMode: String
    let licenseText: String
    let activationDate: Date?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Operasyon Katmanı")
                            .font(QAITokens.Typography.largeTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("Trade, lisans ve canlı adapter davranışlarını tek merkezden yönet.")
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                    }

                    Spacer()

                    AppMarkView(size: 42)
                }

                HStack(spacing: 10) {
                    StatusStrip(label: "Feed", value: effectiveMode, color: effectiveMode == "Canlı" ? QAITheme.success : QAITheme.warning)
                    StatusStrip(label: "Lisans", value: licenseText, color: licenseText == "Enterprise" ? QAITheme.accent : QAITheme.surfaceMuted)
                }

                if let activationDate {
                    Text("Son aktivasyon: \(activationDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(QAITokens.Typography.caption)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }
            }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Text(subtitle)
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(QAITokens.Palette.gold)
            }
            Divider().overlay(QAITokens.Palette.stroke)
        }
    }
}

private struct SettingsMenuRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SliderControl: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Spacer()
                Text(valueText)
                    .font(.caption.monospaced())
                    .foregroundStyle(QAITokens.Palette.gold)
            }
            Slider(value: $value, in: range)
                .tint(QAITokens.Palette.gold)
        }
    }
}

private struct StepperRow: View {
    let title: String
    let valueText: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(valueText)
                    .font(.caption.monospaced())
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Spacer()
            Stepper("", onIncrement: onIncrement, onDecrement: onDecrement)
                .labelsHidden()
                .tint(QAITokens.Palette.gold)
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let icon: String

    init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        Label(title, systemImage: icon)
            .font(QAITokens.Typography.cardTitle)
            .foregroundStyle(QAITokens.Palette.textPrimary)
    }
}

private struct StatusStrip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(QAITokens.Typography.cardTitle)
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(color.opacity(0.16))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private var closeToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS) || os(tvOS) || os(visionOS)
    return .topBarTrailing
    #else
    return .automatic
    #endif
}
