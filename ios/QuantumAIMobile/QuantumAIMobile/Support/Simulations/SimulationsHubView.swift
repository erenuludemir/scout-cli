import SwiftUI

public struct SimulationsHubView: View {
    @ObservedObject private var center = SimulationControlCenter.shared

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SimulationStatusCard()

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Runtime Actions", systemImage: "dial.medium")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)

                        Text("Tüm sürüm aileleri tek target altında derlenmiş Swift katmanları olarak temsil ediliyor. Native Swift modüller doğrudan, Python/Rust/Go/Dataform/Crossplane akışları ise build-safe runtime wrapper olarak çalışıyor.")
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)

                        HStack(spacing: 10) {
                            Button("Catalog Sync") {
                                center.synchronizeCatalog()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(QAITheme.panelBlue)

                            Button("Aktif Sürümü Aç") {
                                center.activate(version: center.selectedVersion)
                            }
                            .buttonStyle(.bordered)
                            .tint(center.selectedVersion.accent)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(center.bundles) { bundle in
                            Button {
                                center.activate(version: bundle.version)
                            } label: {
                                VersionChip(
                                    title: bundle.version.displayName,
                                    icon: bundle.version.icon,
                                    accent: bundle.version.accent,
                                    isSelected: center.selectedVersion == bundle.version,
                                    isActivated: center.isActivated(bundle.version)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }

                NavigationLink {
                    SimulationVersionDetailView(bundle: center.selectedBundle)
                } label: {
                    SelectedBundleCard(bundle: center.selectedBundle, isActivated: center.isActivated(center.selectedVersion))
                }
                .buttonStyle(.plain)

                VStack(spacing: 12) {
                    ForEach(center.bundles) { bundle in
                        NavigationLink {
                            SimulationVersionDetailView(bundle: bundle)
                        } label: {
                            VersionSummaryCard(bundle: bundle, isActivated: center.isActivated(bundle.version))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !center.activityLog.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Simulation Activity", systemImage: "text.line.first.and.arrowtriangle.forward")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(QAITheme.textPrimary)

                            ForEach(Array(center.activityLog.prefix(6).enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(QAITheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, QAITheme.shellHorizontalPadding)
            .padding(.top, QAITheme.shellTopPadding)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(AppBackground())
        .navigationTitle("Simulation Stack")
        .qaiNavigationTitleDisplayMode(.large)
        .task {
            center.bootstrap()
        }
    }
}

public struct SimulationStatusCard: View {
    @ObservedObject private var center = SimulationControlCenter.shared

    public init() {}

    public var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Compiled Version Matrix", systemImage: "square.stack.3d.up.fill")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text("v3, v4, v5, v6, v7, v8, vFinal ve vOmega aileleri tek Swift hedefinde toplanmis durumda.")
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(center.selectedVersion.displayName)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(center.selectedVersion.accent)
                        Text(center.selectedVersion.summary)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(QAITheme.textSecondary)
                            .frame(maxWidth: 128)
                    }
                }

                HStack(spacing: 10) {
                    HubMetric(title: "Sürüm", value: "\(center.totalVersionCount)", accent: QAITheme.panelBlue)
                    HubMetric(title: "Modül", value: "\(center.totalModuleCount)", accent: QAITheme.success)
                    HubMetric(title: "Port", value: "\(center.totalPortedModuleCount)", accent: QAITheme.warning)
                }

                HStack {
                    Label(center.isActivated(center.selectedVersion) ? "Aktif target yüklü" : "Aktif target bekliyor", systemImage: center.isActivated(center.selectedVersion) ? "checkmark.seal.fill" : "hourglass")
                        .font(.caption)
                        .foregroundStyle(center.isActivated(center.selectedVersion) ? QAITheme.success : QAITheme.warning)
                    Spacer()
                    Text(center.syncedAt?.formatted(.dateTime.hour().minute().second()) ?? "Sync yok")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
        }
    }
}

public struct SimulationVersionDetailView: View {
    let bundle: SimulationVersionBundle
    @ObservedObject private var center = SimulationControlCenter.shared

    public init(bundle: SimulationVersionBundle) {
        self.bundle = bundle
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(bundle.version.displayName, systemImage: bundle.version.icon)
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(bundle.version.accent)
                            Spacer()
                            Text(bundle.codename.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(QAITheme.textSecondary)
                        }

                        Text(bundle.overview)
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)

                        HStack(spacing: 10) {
                            HubMetric(title: "Compiled", value: "\(bundle.compiledModuleCount)", accent: bundle.version.accent)
                            HubMetric(title: "Ported", value: "\(bundle.portedModuleCount)", accent: QAITheme.warning)
                        }

                        Button(center.isActivated(bundle.version) ? "Aktif Hedef" : "Bu Sürümü Aktif Et") {
                            center.activate(version: bundle.version)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(bundle.version.accent)
                    }
                }

                ForEach(bundle.modules) { module in
                    SimulationModuleCard(module: module)
                }
            }
            .padding(.horizontal, QAITheme.shellHorizontalPadding)
            .padding(.top, QAITheme.shellTopPadding)
            .padding(.bottom, QAITheme.dockedBottomPadding)
        }
        .background(AppBackground())
        .navigationTitle(bundle.version.displayName)
    }
}

private struct SelectedBundleCard: View {
    let bundle: SimulationVersionBundle
    let isActivated: Bool

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(bundle.version.displayName, systemImage: bundle.version.icon)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(bundle.version.accent)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(QAITheme.textSecondary)
                }

                Text(bundle.overview)
                    .font(.subheadline)
                    .foregroundStyle(QAITheme.textSecondary)

                HStack(spacing: 10) {
                    HubMetric(title: "Native", value: "\(bundle.compiledModuleCount - bundle.portedModuleCount)", accent: QAITheme.panelBlue)
                    HubMetric(title: "Ported", value: "\(bundle.portedModuleCount)", accent: QAITheme.warning)
                }

                Label(isActivated ? "Bu sürüm aktif target olarak işaretli." : "Detaya girip bu sürümü aktive edebilirsiniz.", systemImage: isActivated ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(isActivated ? QAITheme.success : QAITheme.textSecondary)
            }
        }
    }
}

private struct VersionSummaryCard: View {
    let bundle: SimulationVersionBundle
    let isActivated: Bool

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(bundle.version.displayName, systemImage: bundle.version.icon)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(bundle.version.accent)
                    Spacer()
                    if isActivated {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(QAITheme.success)
                    }
                }

                Text(bundle.codename)
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)

                Text(bundle.overview)
                    .font(.subheadline)
                    .foregroundStyle(QAITheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    HubMetric(title: "Modül", value: "\(bundle.compiledModuleCount)", accent: bundle.version.accent)
                    HubMetric(title: "Port", value: "\(bundle.portedModuleCount)", accent: QAITheme.warning)
                }
            }
        }
    }
}

private struct SimulationModuleCard: View {
    let module: SimulationModule

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(QAITheme.textPrimary)
                        Text(module.summary)
                            .font(.subheadline)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                    Spacer()
                    Text(module.integrationMode.title)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(QAITheme.surfaceMuted.opacity(0.55))
                        .clipShape(Capsule())
                        .foregroundStyle(QAITheme.textPrimary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(module.sourceKinds, id: \.rawValue) { source in
                            Text(source.badge)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(source.tint.opacity(0.18))
                                .clipShape(Capsule())
                                .foregroundStyle(source.tint)
                        }
                    }
                }

                Text(module.integrationMode.detail)
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Origin")
                        .font(.caption)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text(module.originHint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(QAITheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Capabilities")
                        .font(.caption)
                        .foregroundStyle(QAITheme.textSecondary)
                    ForEach(module.capabilities, id: \.self) { capability in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(module.version.accent)
                                .frame(width: 6, height: 6)
                            Text(capability)
                                .font(.caption)
                                .foregroundStyle(QAITheme.textPrimary)
                        }
                    }
                }
            }
        }
    }
}

private struct VersionChip: View {
    let title: String
    let icon: String
    let accent: Color
    let isSelected: Bool
    let isActivated: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            if isActivated {
                Circle()
                    .fill(QAITheme.success)
                    .frame(width: 7, height: 7)
            }
        }
        .foregroundStyle(isSelected ? QAITheme.background : QAITheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? accent : QAITheme.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSelected ? accent.opacity(0.2) : QAITheme.border, lineWidth: 1)
        )
    }
}

private struct HubMetric: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(QAITheme.textSecondary)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(QAITheme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: QAITheme.compactInnerCornerRadius, style: .continuous))
    }
}
