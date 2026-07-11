import SwiftUI

public struct IntelligenceCenterView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedCategory: TrainingCategory? = nil

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
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
        .background(AppBackground())
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
                                Text(preset.requiresLicense ? "Advanced" : "Hazır")
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
        .background(AppBackground())
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
    @State private var actionStatus = "Runtime snapshot bekleniyor"
    @State private var isRunningAction = false

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

                runtimeOperationsCard

                if !env.runtimeAdmin.runbook.trendPoints.isEmpty {
                    runtimeTrendCard
                }

                if !env.runtimeAdmin.runbook.topicActivity.isEmpty {
                    topicActivityCard
                }

                if !env.runtimeAdmin.recentAudits.isEmpty {
                    runtimeAuditCard
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
        .background(AppBackground())
        .navigationTitle("Runbook")
        .qaiNavigationTitleDisplayMode(.inline)
        .task {
            env.training.loadIfNeeded()
            let refreshed = await env.runtimeAdmin.refresh()
            actionStatus = refreshed ? env.runtimeAdmin.lastAction : (env.runtimeAdmin.lastError ?? "Runtime snapshot alınamadı")
        }
    }

    private var runbookSections: [TrainingSection] {
        env.training.guide.sections.filter {
            $0.category == .operations || $0.category == .security || $0.category == .deployment || $0.category == .api
        }
    }

    private var runtimeOperationsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Canlı Runtime Runbook")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text("Backend readiness, outbox durumu ve replay/drain operasyonları bu yüzeyden yönetilir.")
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                    Spacer()
                    NavigationLink {
                        HQAdminView(showsBackButton: true)
                    } label: {
                        Text("HQ Admin")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(QAITheme.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(QAITheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    BrainMetricChip(title: "API", value: env.runtimeAdmin.isReady ? "READY" : env.runtimeAdmin.readiness.status.uppercased(), tint: env.runtimeAdmin.isReady ? QAITheme.success : QAITheme.warning)
                    BrainMetricChip(title: "Bağımlılık", value: env.runtimeAdmin.dependencySummary, tint: QAITheme.accent)
                    BrainMetricChip(title: "Due", value: "\(env.runtimeAdmin.outbox.due)", tint: env.runtimeAdmin.outbox.due > 0 ? QAITheme.warning : QAITheme.success)
                    BrainMetricChip(title: "DLQ", value: "\(env.runtimeAdmin.outbox.deadLetter)", tint: env.runtimeAdmin.outbox.deadLetter > 0 ? QAITheme.error : QAITheme.panelBlue)
                }

                Text("Audit: \(env.runtimeAdmin.auditSummary)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QAITheme.textSecondary)

                if !env.runtimeAdmin.runbook.topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic Rotaları")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(QAITheme.textSecondary)
                        ForEach(env.runtimeAdmin.runbook.topics.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(QAITheme.textPrimary)
                                Spacer()
                                Text(env.runtimeAdmin.runbook.topics[key] ?? "-")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(QAITheme.textSecondary)
                            }
                        }
                    }
                }

                Text(actionStatus)
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)

                HStack(spacing: 10) {
                    actionButton(title: env.runtimeAdmin.isRefreshing ? "Yenileniyor..." : "Yenile", disabled: isRunningAction || env.runtimeAdmin.isRefreshing) {
                        let refreshed = await env.runtimeAdmin.refresh()
                        actionStatus = refreshed ? env.runtimeAdmin.lastAction : (env.runtimeAdmin.lastError ?? "Runtime yenileme başarısız")
                    }
                    actionButton(title: "Drain", disabled: isRunningAction) {
                        let result = await env.runtimeAdmin.drainOutbox()
                        actionStatus = result.map { "Drain sent \($0.sent) • failed \($0.failed) • dlq \($0.deadLettered)" } ?? (env.runtimeAdmin.lastError ?? "Drain başarısız")
                    }
                    actionButton(title: "Replay DLQ", disabled: isRunningAction || env.runtimeAdmin.outbox.deadLetter == 0) {
                        let replayed = await env.runtimeAdmin.replayDeadLetters(limit: 25)
                        actionStatus = replayed.map { "Replay dead letters \($0)" } ?? (env.runtimeAdmin.lastError ?? "Replay başarısız")
                    }
                }
            }
        }
    }

    private var runtimeAuditCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Son Backend Audit İzleri")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                ForEach(env.runtimeAdmin.recentAudits.prefix(6)) { audit in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(audit.action.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(QAITheme.textPrimary)
                            Spacer()
                            Text(audit.createdAtText)
                                .font(.caption.monospaced())
                                .foregroundStyle(QAITheme.textSecondary)
                        }
                        Text("\(audit.topic) • \(audit.status)")
                            .font(.caption)
                            .foregroundStyle(audit.status == "publish_failed" ? QAITheme.error : QAITheme.textSecondary)
                        if let detail = audit.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(QAITheme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(auditTint(audit))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var runtimeTrendCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Native Runtime Trends")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                RuntimeSparklineCard(
                    title: "Outbox Pressure",
                    subtitle: "due / failed / dlq",
                    series: [
                        RuntimeSparklineSeries(label: "Due", values: env.runtimeAdmin.runbook.trendPoints.map(\.outboxDue), tint: QAITheme.warning),
                        RuntimeSparklineSeries(label: "Failed", values: env.runtimeAdmin.runbook.trendPoints.map(\.outboxFailed), tint: QAITheme.panelBlue),
                        RuntimeSparklineSeries(label: "DLQ", values: env.runtimeAdmin.runbook.trendPoints.map(\.outboxDeadLetter), tint: QAITheme.error)
                    ]
                )

                RuntimeSparklineCard(
                    title: "Relay Activity",
                    subtitle: "sent / replay / dead-letter",
                    series: [
                        RuntimeSparklineSeries(label: "Sent", values: env.runtimeAdmin.runbook.trendPoints.map(\.relaySent), tint: QAITheme.success),
                        RuntimeSparklineSeries(label: "Replay", values: env.runtimeAdmin.runbook.trendPoints.map(\.relayReplay), tint: QAITheme.warning),
                        RuntimeSparklineSeries(label: "DLQ", values: env.runtimeAdmin.runbook.trendPoints.map(\.relayDeadLetter), tint: QAITheme.error)
                    ]
                )
            }
        }
    }

    private var topicActivityCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Topic Activity")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(QAITheme.textPrimary)

                ForEach(env.runtimeAdmin.runbook.topicActivity.prefix(6)) { activity in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(activity.topic)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(QAITheme.textPrimary)
                            Spacer()
                            Text(activity.lastSeenAtText)
                                .font(.caption.monospaced())
                                .foregroundStyle(QAITheme.textSecondary)
                        }

                        HStack(spacing: 10) {
                            BrainMetricChip(title: "Sent", value: "\(activity.sentCount)", tint: QAITheme.success)
                            BrainMetricChip(title: "Replay", value: "\(activity.replayCount)", tint: QAITheme.warning)
                            BrainMetricChip(title: "DLQ", value: "\(activity.deadLetterCount)", tint: activity.deadLetterCount > 0 ? QAITheme.error : QAITheme.panelBlue)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(QAITheme.surfaceMuted.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func actionButton(
        title: String,
        disabled: Bool,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        Button {
            guard !disabled else { return }
            isRunningAction = true
            Task { @MainActor in
                await action()
                isRunningAction = false
            }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(disabled ? QAITheme.textSecondary : QAITheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(disabled ? QAITheme.panelBlue.opacity(0.45) : QAITheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func auditTint(_ audit: RuntimeAdminAuditEntry) -> Color {
        if audit.action == "dead_letter" || audit.status == "publish_failed" {
            return QAITheme.error.opacity(0.16)
        }
        if audit.action == "replay" {
            return QAITheme.warning.opacity(0.16)
        }
        return QAITheme.success.opacity(0.14)
    }
}

private struct RuntimeSparklineSeries: Identifiable {
    let id = UUID()
    let label: String
    let values: [Int]
    let tint: Color
}

private struct RuntimeSparklineCard: View {
    let title: String
    let subtitle: String
    let series: [RuntimeSparklineSeries]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(QAITheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(QAITheme.textSecondary)

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(QAITheme.surfaceMuted.opacity(0.26))
                    ForEach(series) { item in
                        RuntimeSparklineShape(values: item.values)
                            .stroke(item.tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                    }
                }
            }
            .frame(height: 84)

            HStack(spacing: 10) {
                ForEach(series) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.tint)
                            .frame(width: 8, height: 8)
                        Text("\(item.label) \(item.values.last ?? 0)")
                            .font(.caption.monospaced())
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(QAITheme.surfaceMuted.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RuntimeSparklineShape: Shape {
    let values: [Int]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let maxValue = max(values.max() ?? 0, 1)
        let stepX = rect.width / CGFloat(max(values.count - 1, 1))

        return Path { path in
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let ratio = CGFloat(value) / CGFloat(maxValue)
                let y = rect.maxY - (ratio * rect.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
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
        .background(AppBackground())
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
