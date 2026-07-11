import SwiftUI

public struct AutonomyStudioView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    @ObservedObject private var telepathy = TelepathyGateway.shared
    @ObservedObject private var autonomy = AutonomyControlCenter.shared

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Autonomy Studio", showsBackButton: true, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Native dashboard yüzeyleri")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text("Quantum ops, digital twin, citadel, neural command ve training yüzeyleri artık AppShell içinde görünür ve tek merkezden erişilebilir.")
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStudioPulseTile(
                                title: "Twin",
                                value: "%\(Int(twin.syncProgress * 100))",
                                tint: QAITokens.Palette.chipBlue
                            )
                            AutonomyStudioPulseTile(
                                title: "Citadel",
                                value: citadel.isSealed ? "LOCKED" : "STANDBY",
                                tint: QAITokens.Palette.chipAmber
                            )
                            AutonomyStudioPulseTile(
                                title: "Neural",
                                value: String(format: "%.3f ms", telepathy.lastLatencyMs),
                                tint: QAITokens.Palette.chipTeal
                            )
                        }

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStudioPulseTile(
                                title: "Training",
                                value: env.trainingJourney.currentStep.title,
                                tint: QAITokens.Palette.cardElevated
                            )
                            AutonomyStudioPulseTile(
                                title: "SLO",
                                value: percentText(autonomy.reliability.effectiveSuccessRate),
                                tint: QAITokens.Palette.gold.opacity(0.22)
                            )
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Dashboard Blokları")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        NavigationLink {
                            QuantumPerformanceDashboard(showsBackButton: true)
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Quantum Ops",
                                subtitle: "QKD / PQC metrikleri, tehdit görünümü ve operasyon terminali",
                                icon: "shield.lefthalf.filled",
                                tint: QAITokens.Palette.chipBlue
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            MegaPipelineMasterView()
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Mega Pipeline",
                                subtitle: "Merkezi sinir, telemetry, bilişsel kök ve ajan orkestrasyonu",
                                icon: "point.3.connected.trianglepath.dotted",
                                tint: QAITokens.Palette.chipTeal
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            DigitalTwinView(showsBackButton: true)
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Digital Twin",
                                subtitle: twin.statusText,
                                icon: "person.2.wave.2.fill",
                                tint: QAITokens.Palette.cardElevated
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CitadelStatusView(showsBackButton: true)
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Smart Citadel",
                                subtitle: "Fiziksel anchor, power grid ve uplink durumu",
                                icon: "building.2.crop.circle",
                                tint: QAITokens.Palette.chipAmber
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            NeuralCommandView(showsBackButton: true)
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Neural Command",
                                subtitle: "BCI decoder, niyet akışı ve latency rayı",
                                icon: "brain.head.profile",
                                tint: QAITokens.Palette.chipTeal
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            EternityView(showsBackButton: true)
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Dashboard ETERNITY",
                                subtitle: "Twin, citadel ve neural durumu aynı panoramada",
                                icon: "sparkles.rectangle.stack",
                                tint: QAITokens.Palette.gold.opacity(0.22)
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TrainingJourneyView()
                        } label: {
                            AutonomyStudioDestinationRow(
                                title: "Training Journey",
                                subtitle: "Adım adım onboarding, quiz ve kaldığın yer",
                                icon: "figure.walk.motion",
                                tint: QAITokens.Palette.cardElevated
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, QAITokens.Layout.screenPadding)
            .padding(.top, QAITokens.Spacing.s)
            .padding(.bottom, QAITokens.Layout.dockedBottomClearance)
        }
        .accessibilityIdentifier("autonomy-studio-screen")
        .background(AppBackground())
        .screenNavigationChromeHidden()
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }
}

private struct AutonomyStudioDestinationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: QAITokens.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .frame(width: 42, height: 42)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QAITokens.Typography.bodyStrong)
                    .foregroundStyle(QAITokens.Palette.textPrimary)
                Text(subtitle)
                    .font(QAITokens.Typography.caption)
                    .foregroundStyle(QAITokens.Palette.textSecondary)
                    .lineLimit(nil)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(QAITokens.Palette.textSecondary)
        }
        .padding(QAITokens.Spacing.m)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AutonomyStudioPulseTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QAITokens.Typography.caption)
                .foregroundStyle(QAITokens.Palette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITokens.Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
