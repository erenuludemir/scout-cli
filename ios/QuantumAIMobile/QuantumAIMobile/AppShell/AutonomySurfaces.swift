import SwiftUI

public struct DigitalTwinView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Digital Twin", showsBackButton: showsBackButton, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Cognitive Twin Registry")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(twin.statusText)
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Heir", value: twin.heirName, tint: QAITokens.Palette.chipBlue)
                            AutonomyStatTile(title: "Mode", value: twin.mentorMode, tint: QAITokens.Palette.chipTeal)
                        }

                        ProgressView(value: twin.syncProgress) {
                            Text("Senkronizasyon")
                                .font(QAITokens.Typography.caption)
                                .foregroundStyle(QAITokens.Palette.textSecondary)
                        } currentValueLabel: {
                            Text("%\(Int(twin.syncProgress * 100))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITokens.Palette.gold)
                        }
                        .tint(QAITokens.Palette.teal)

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Maturity", value: "%\(Int(twin.maturityLevel * 100))", tint: QAITokens.Palette.chipAmber)
                            AutonomyStatTile(title: "Knowledge", value: twin.knowledgeBase, tint: QAITokens.Palette.cardElevated)
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

public struct CitadelStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Smart Citadel", showsBackButton: showsBackButton, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Barakfakih Physical Anchor")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        Text(citadel.isSealed ? "Egemen kale muhurlu" : "Citadel standby modunda")
                            .font(QAITokens.Typography.bodyStrong)
                            .foregroundStyle(citadel.isSealed ? QAITokens.Palette.teal : QAITokens.Palette.warning)

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Anchor", value: citadel.anchorID.isEmpty ? "Bekleniyor" : citadel.anchorID, tint: QAITokens.Palette.chipBlue)
                            AutonomyStatTile(title: "Power", value: citadel.powerGridStatus, tint: QAITokens.Palette.chipAmber)
                        }

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Uplink", value: citadel.uplinkStatus, tint: QAITokens.Palette.chipTeal)
                            AutonomyStatTile(title: "Integrity", value: "%\(Int(citadel.integrity * 100))", tint: QAITokens.Palette.cardElevated)
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

public struct NeuralCommandView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var telepathy = TelepathyGateway.shared
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Neural Command", showsBackButton: showsBackButton, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        HStack(spacing: QAITokens.Spacing.m) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(QAITokens.Palette.teal)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Neural command rail")
                                    .font(QAITokens.Typography.cardTitle)
                                    .foregroundStyle(QAITokens.Palette.textPrimary)
                                Text("Gercek BCI degil; komut akislarini dusuk yuke sahip bir karar rayinda ozetler.")
                                    .font(QAITokens.Typography.caption)
                                    .foregroundStyle(QAITokens.Palette.textSecondary)
                                    .lineLimit(nil)
                            }
                        }

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Sync", value: "%\(Int(telepathy.neuralSyncPhase * 100))", tint: QAITokens.Palette.chipBlue)
                            AutonomyStatTile(title: "Intent", value: telepathy.lastIntentCode, tint: QAITokens.Palette.chipTeal)
                            AutonomyStatTile(title: "Latency", value: String(format: "%.3f ms", telepathy.lastLatencyMs), tint: QAITokens.Palette.chipAmber)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Son islenen komutlar")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        ForEach(Array(telepathy.activeThoughts.enumerated()), id: \.offset) { index, thought in
                            HStack(spacing: QAITokens.Spacing.s) {
                                Text("#\(index + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.gold)
                                    .frame(width: 28)
                                Text(thought)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.textPrimary)
                                Spacer()
                                Text("EXEC")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(QAITokens.Palette.teal)
                            }
                            .padding(QAITokens.Spacing.s)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

public struct EternityView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var twin = CognitiveTwinRegistry.shared
    @ObservedObject private var citadel = BarakfakihCitadel.shared
    @ObservedObject private var telepathy = TelepathyGateway.shared
    private let showsBackButton: Bool

    public init(showsBackButton: Bool = false) {
        self.showsBackButton = showsBackButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: QAITokens.Spacing.l) {
                ScreenHeader(title: "Eternity Relay", showsBackButton: showsBackButton, onBack: { dismiss() })

                GlassCard {
                    VStack(alignment: .leading, spacing: QAITokens.Spacing.m) {
                        Text("Future-readiness composite")
                            .font(QAITokens.Typography.cardTitle)
                            .foregroundStyle(QAITokens.Palette.textPrimary)

                        HStack(spacing: QAITokens.Spacing.s) {
                            AutonomyStatTile(title: "Twin", value: "%\(Int(twin.syncProgress * 100))", tint: QAITokens.Palette.chipBlue)
                            AutonomyStatTile(title: "Citadel", value: citadel.isSealed ? "Locked" : "Standby", tint: QAITokens.Palette.chipAmber)
                            AutonomyStatTile(title: "Neural", value: "%\(Int(telepathy.neuralSyncPhase * 100))", tint: QAITokens.Palette.chipTeal)
                        }

                        Text("Bu yuzey gercek dunyada telepati veya kimlik dogrulama yapmaz; quantum ops, komut rayi ve fiziksel anchor telemetrisinin kontrollu ozetidir.")
                            .font(QAITokens.Typography.body)
                            .foregroundStyle(QAITokens.Palette.textSecondary)
                            .lineLimit(nil)
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

private struct AutonomyStatTile: View {
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
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(QAITokens.Spacing.s)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
