import SwiftUI

struct RuntimeTrendDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var drilldown = RuntimeAdminDrilldownSnapshot.empty
    @State private var isLoading = false

    let lane: HQRuntimeTrendLane

    private var snapshot: HQRuntimeTrendSnapshot {
        lane.detailSnapshot
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(
                    title: lane.title,
                    showsBackButton: true,
                    onBack: { dismiss() }
                )

                heroCard
                chartCard
                liveDrilldownCard
                insightCard
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .background(AppBackground())
        .screenNavigationChromeHidden()
        .task {
            await loadDrilldown()
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Runtime Trend Detail")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text(insightText)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)

                LazyVGrid(columns: summaryColumns, spacing: QAITokens.Spacing.s) {
                    metricCard(title: "Current", value: formatted(snapshot.current))
                    metricCard(title: "Peak", value: formatted(snapshot.peak))
                    metricCard(title: "Average", value: formatted(snapshot.average))
                    metricCard(title: "Delta", value: signed(snapshot.delta))
                }
            }
        }
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                Text("Window")
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)

                RuntimeTrendSparkline(values: lane.points)
                    .stroke(
                        lane.tint,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(height: 180)
                    .padding(QAITokens.Spacing.s)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack {
                    Text("Samples \(max(lane.points.count, 1))")
                    Spacer()
                    Text(lane.detail.uppercased())
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textSecondary)
            }
        }
    }

    private var insightCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                Text("Operator Note")
                    .font(QAITokens.Typography.cardTitle)
                    .foregroundStyle(QAITokens.Palette.textPrimary)

                Text(recommendationText)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }
        }
    }

    private var liveDrilldownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                HStack {
                    Text("Live Drilldown")
                        .font(QAITokens.Typography.cardTitle)
                        .foregroundStyle(QAITokens.Palette.textPrimary)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(QAITokens.Palette.gold)
                    } else {
                        Text(drilldown.metric.isEmpty ? "local" : drilldown.metric.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITokens.Palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(QAITokens.Palette.chipTeal)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: QAITokens.Spacing.s) {
                    metricCard(title: "Checks", value: drilldown.dependencySummary)
                    metricCard(title: "Outbox", value: "Due \(drilldown.outbox.due) • DLQ \(drilldown.outbox.deadLetter)")
                }

                if drilldown.recentAudits.isEmpty && drilldown.events.isEmpty {
                    Text("Bu trend icin backend tarafinda yeni audit veya event yok. Operatör yine de HQ Admin zaman cizelgesini ve outbox ekranini kontrol etmeli.")
                        .font(QAITokens.Typography.body)
                        .foregroundStyle(QAITokens.Palette.textSecondary)
                        .lineLimit(nil)
                } else {
                    if !drilldown.recentAudits.isEmpty {
                        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                            Text("Recent Audits")
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                            ForEach(drilldown.recentAudits.prefix(4)) { audit in
                                auditRow(audit)
                            }
                        }
                    }

                    if !drilldown.events.isEmpty {
                        VStack(alignment: .leading, spacing: QAITokens.Spacing.s) {
                            Text("Related Outbox")
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                            ForEach(drilldown.events.prefix(4)) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
        }
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: QAITokens.Spacing.s)]
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.m)
        .background(QAITokens.Palette.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func auditRow(_ audit: RuntimeAdminAuditEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(audit.action.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Spacer()
                Text(audit.createdAtText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Text("\(audit.topic) • \(audit.status)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(audit.status == "publish_failed" ? QAITokens.Palette.warning : QAITokens.Palette.textSecondary)
            if let detail = audit.detail, !detail.isEmpty {
                Text(detail)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func eventRow(_ event: RuntimeAdminEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.aggregateID.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Spacer()
                Text("#\(event.id)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(QAITokens.Palette.textSecondary)
            }
            Text("\(event.status) • attempts \(event.attempts)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(event.status == "dead_letter" ? QAITokens.Palette.warning : QAITokens.Palette.textSecondary)
            if let lastError = event.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(QAITokens.Typography.body)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(QAITokens.Spacing.s)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formatted(_ value: Double) -> String {
        if lane.title == "Dependencies" || lane.title == "Deps" {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func signed(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(formatted(value))"
    }

    private var insightText: String {
        switch lane.title.lowercased() {
        case let title where title.contains("queue"):
            return "Queue baskisi, due ve dead-letter toplam yukunu gosterir. Yukseldikce replay ve drain aksiyonlari one alinmali."
        case let title where title.contains("relay"):
            return "Relay sayaci publish akisinin sagligini yansitir. Artis devam ediyorsa runtime akiyor, sabit kalirsa worker zinciri incelenmeli."
        case let title where title.contains("replay"):
            return "Replay trendi operator mudahalesi veya otomatik toparlanma frekansini gosterir. Artis suruyorsa tekrar eden ariza vardir."
        default:
            return "Dependency trendi, runtime omurgasinin ne kadarinin ayakta oldugunu gosterir. Dusus varsa servis baglantilari ve ready zinciri incelenmeli."
        }
    }

    private var recommendationText: String {
        if lane.title.lowercased().contains("queue") && snapshot.current > 0 {
            return "Queue sifir degil. Once HQ Admin icinden replay veya drain calistir, sonra outbox audit zincirini kontrol et."
        }
        if lane.title.lowercased().contains("replay") && snapshot.delta > 0 {
            return "Replay artiyor. Bu, hata duzeltme yerine tekrar eden ariza paterni olduguna isaret eder; DLQ konusu ve son audit detaylari eslestirilmeli."
        }
        if (lane.title == "Dependencies" || lane.title == "Deps") && snapshot.current < snapshot.peak {
            return "Dependency sayisi zirvenin altinda. Redis/Postgres/Kafka ready kontrolleri tekrar okunmali."
        }
        return "Trend stabil. Bu karti operatör için erken uyari paneli olarak kullan ve ani sapmalarda HQ Admin olay zaman cizelgesine gec."
    }

    @MainActor
    private func loadDrilldown() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            drilldown = try await env.runtimeAdmin.fetchDrilldown(for: lane)
        } catch {
            drilldown = .empty
        }
    }
}

private struct RuntimeTrendSparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let span = max(maxValue - minValue, 1)

        return Path { path in
            for (index, value) in values.enumerated() {
                let x = rect.minX + (rect.width * CGFloat(index) / CGFloat(values.count - 1))
                let normalized = (value - minValue) / span
                let y = rect.maxY - (rect.height * CGFloat(normalized))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
