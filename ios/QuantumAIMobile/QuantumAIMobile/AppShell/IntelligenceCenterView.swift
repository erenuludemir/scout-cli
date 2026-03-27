import SwiftUI

public struct IntelligenceCenterView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedCategory: TrainingCategory? = nil

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                CardView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Beyin Merkezi")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(env.training.guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)

                        HStack(spacing: 10) {
                            BrainMetricChip(title: "Kaynak", value: "8590 satır HTML", tint: QAITheme.accent)
                            BrainMetricChip(title: "Bölüm", value: "\(env.training.guide.sections.count)", tint: QAITheme.success)
                            BrainMetricChip(title: "Preset", value: "\(env.training.guide.presets.count)", tint: QAITheme.warning)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Bağlamsal Öneriler", systemImage: "sparkles")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(QAITheme.textPrimary)
                            Spacer()
                            Button("Yenile") {
                                env.training.loadIfNeeded()
                            }
                            .font(.caption.bold())
                            .foregroundStyle(QAITheme.accent)
                        }

                        if recommendations.isEmpty {
                            Text("Yapay zeka katmanı için rehber bölümleri hazırlanıyor. Kaynağı yeniden yüklemek için yenileyi kullanın.")
                                .font(.subheadline)
                                .foregroundStyle(QAITheme.textSecondary)
                        } else {
                            ForEach(recommendations) { item in
                                NavigationLink {
                                    TrainingSectionDetailView(section: env.training.section(withID: item.sourceSectionID))
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.system(.headline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(QAITheme.textPrimary)
                                        Text(item.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(QAITheme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(QAITheme.surfaceMuted.opacity(0.45))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Kategori Filtreleri", systemImage: "slider.horizontal.3")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "Tümü",
                                    isSelected: selectedCategory == nil,
                                    action: { selectedCategory = nil }
                                )
                                ForEach(TrainingCategory.allCases) { category in
                                    FilterChip(
                                        title: category.title,
                                        isSelected: selectedCategory == category,
                                        action: { selectedCategory = category }
                                    )
                                }
                            }
                        }
                    }
                }

                ForEach(filteredSections) { section in
                    NavigationLink {
                        TrainingSectionDetailView(section: section)
                    } label: {
                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(section.title)
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(QAITheme.textPrimary)
                                    Spacer()
                                    Text(section.category.title)
                                        .font(.caption.bold())
                                        .foregroundStyle(QAITheme.textSecondary)
                                }

                                Text(section.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(QAITheme.textSecondary)

                                HStack(spacing: 10) {
                                    BrainMetricChip(title: "Kod", value: "\(section.codeBlockCount)", tint: QAITheme.accent)
                                    BrainMetricChip(title: "Diyagram", value: "\(section.diagramCount)", tint: QAITheme.success)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(QAITheme.shellGradient.ignoresSafeArea())
        .navigationTitle("Beyin Merkezi")
        .qaiNavigationTitleDisplayMode(.inline)
        .task {
            env.training.loadIfNeeded()
        }
    }

    private var filteredSections: [TrainingSection] {
        if let selectedCategory {
            return env.training.sections(for: selectedCategory)
        }
        return env.training.guide.sections
    }

    private var recommendations: [TrainingRecommendation] {
        env.training.contextualRecommendations(
            for: BrainContext(
                queueDepth: env.storage.queueDepth(),
                retryRate: env.sync.retryRate(),
                estimatedPnL: env.bot.estimatedPnL(currentPrice: env.market.last?.price),
                activeOrders: env.bot.activeOrders.count,
                usesSimulation: env.runtimeUsesSimulation,
                isAuthenticated: env.settings.isAuthenticated,
                selectedSymbol: env.settings.selectedSymbol,
                isCopyTradeActive: env.copyTrade.isActive
            )
        )
    }
}

public struct StrategyLibraryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var status = "Preset seçildiğinde ayarlar otomatik uygulanır."

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Strateji Kütüphanesi")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                }

                ForEach(env.training.guide.presets) { preset in
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.title)
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(QAITheme.textPrimary)
                                    Text(preset.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(QAITheme.textSecondary)
                                }
                                Spacer()
                                Text(preset.requiresLicense ? "Premium" : "Hazır")
                                    .font(.caption.bold())
                                    .foregroundStyle(preset.requiresLicense ? QAITheme.accent : QAITheme.success)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                BrainMetricChip(title: "DCA", value: "$\(Int(preset.dcaAmount))", tint: QAITheme.accent)
                                BrainMetricChip(title: "Periyot", value: "\(preset.dcaPeriodSec) sn", tint: QAITheme.surfaceMuted)
                                BrainMetricChip(title: "Grid", value: "\(preset.gridSteps) kademe", tint: QAITheme.success)
                                BrainMetricChip(title: "Copy", value: String(format: "%.2fx", preset.copyRatio), tint: QAITheme.warning)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text("Preset Uygula")
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(canApply(preset) ? QAITheme.background : QAITheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(canApply(preset) ? QAITheme.accent : QAITheme.surfaceMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(!canApply(preset))

                                NavigationLink {
                                    TrainingSectionDetailView(section: env.training.section(withID: preset.sourceSectionID))
                                } label: {
                                    Text("Kaynağı Aç")
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(QAITheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(QAITheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if env.training.guide.presets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preset kaynağı henüz hazır değil")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(QAITheme.textPrimary)
                            Text("Eğitim rehberi tekrar yüklendiğinde strateji presetleri burada aktifleşir.")
                                .font(.subheadline)
                                .foregroundStyle(QAITheme.textSecondary)
                            PrimaryButton(title: "Kaynağı Yenile", action: {
                                env.training.loadIfNeeded()
                            })
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(QAITheme.shellGradient.ignoresSafeArea())
        .navigationTitle("Strateji Kütüphanesi")
        .qaiNavigationTitleDisplayMode(.inline)
        .task {
            env.training.loadIfNeeded()
        }
    }

    private func canApply(_ preset: StrategyPreset) -> Bool {
        !preset.requiresLicense || env.settings.isAuthenticated
    }

    private func applyPreset(_ preset: StrategyPreset) {
        env.applyPreset(preset)
        status = "\(preset.title) uygulandı. Parametreler ve çalışma modu güncellendi."
    }
}

public struct RunbookCenterView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Runbook ve Operasyon")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text("Operasyon, güvenlik, deployment ve API bölümlerinden türetilen hızlı erişim merkezi.")
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                }

                ForEach(runbookSections) { section in
                    NavigationLink {
                        TrainingSectionDetailView(section: section)
                    } label: {
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(QAITheme.textPrimary)
                                Text(section.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(QAITheme.textSecondary)
                                if !section.highlights.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(section.highlights.prefix(3), id: \.self) { item in
                                            Text("• \(item)")
                                                .font(.caption)
                                                .foregroundStyle(QAITheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(QAITheme.shellGradient.ignoresSafeArea())
        .navigationTitle("Runbook")
        .qaiNavigationTitleDisplayMode(.inline)
        .task {
            env.training.loadIfNeeded()
        }
    }

    private var runbookSections: [TrainingSection] {
        env.training.guide.sections.filter {
            $0.category == .operations || $0.category == .security || $0.category == .deployment || $0.category == .api
        }
    }
}

private struct TrainingSectionDetailView: View {
    let section: TrainingSection?

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let section {
                VStack(spacing: 18) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(section.title)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(QAITheme.textPrimary)
                            Text(section.summary)
                                .font(.subheadline)
                                .foregroundStyle(QAITheme.textSecondary)

                            HStack(spacing: 10) {
                                BrainMetricChip(title: "Kategori", value: section.category.title, tint: QAITheme.accent)
                                BrainMetricChip(title: "Kod", value: "\(section.codeBlockCount)", tint: QAITheme.success)
                                BrainMetricChip(title: "Diyagram", value: "\(section.diagramCount)", tint: QAITheme.warning)
                            }
                        }
                    }

                    if !section.highlights.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Öne Çıkan Satırlar", systemImage: "list.bullet")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(QAITheme.textPrimary)
                                ForEach(section.highlights, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.subheadline)
                                        .foregroundStyle(QAITheme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, QAITheme.dockedBottomPadding)
            } else {
                CardView {
                    Text("İlgili bölüm bulunamadı.")
                        .foregroundStyle(QAITheme.textSecondary)
                }
                .padding(16)
                .padding(.bottom, QAITheme.dockedBottomPadding)
            }
        }
        .background(QAITheme.shellGradient.ignoresSafeArea())
        .navigationTitle(section?.title ?? "Kaynak")
        .qaiNavigationTitleDisplayMode(.inline)
    }
}

private struct BrainMetricChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(QAITheme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(QAITheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? QAITheme.background : QAITheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? QAITheme.accent : QAITheme.surfaceMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
