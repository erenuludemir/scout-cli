import Foundation
import SwiftUI

public enum SimulationVersion: String, CaseIterable, Identifiable, Hashable {
    case v3
    case v4
    case v5
    case v6
    case v7
    case v8
    case vFinal
    case vOmega

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .v3: return "v3 Core"
        case .v4: return "v4 Alpha"
        case .v5: return "v5 HFT"
        case .v6: return "v6 Interstellar"
        case .v7: return "v7 Singularity"
        case .v8: return "v8 FinOps"
        case .vFinal: return "vFinal Sovereign"
        case .vOmega: return "vOmega"
        }
    }

    public var icon: String {
        switch self {
        case .v3: return "shippingbox.fill"
        case .v4: return "brain"
        case .v5: return "bolt.fill"
        case .v6: return "sparkles"
        case .v7: return "waveform.path.ecg"
        case .v8: return "building.columns.fill"
        case .vFinal: return "crown.fill"
        case .vOmega: return "infinity"
        }
    }

    public var accent: Color {
        switch self {
        case .v3: return QAITheme.panelBlue
        case .v4: return QAITheme.accent
        case .v5: return QAITheme.warning
        case .v6: return QAITheme.success
        case .v7: return Color.pink
        case .v8: return Color.cyan
        case .vFinal: return Color.yellow
        case .vOmega: return Color.purple
        }
    }

    public var summary: String {
        switch self {
        case .v3:
            return "Mega pipeline, partner, property ve genesis omurgasi."
        case .v4:
            return "Otonom ogrenme, DeFi, governance ve healer katmani."
        case .v5:
            return "HFT, CBDC, kuantum ajan ve sovereign command terminali."
        case .v6:
            return "Interstellar pulse, lazer baglantisi ve audit vault katmani."
        case .v7:
            return "Singularity mesh, neural governance, isolation ve orbital seed."
        case .v8:
            return "FinOps ambar, QKD IaC, onboarding CLI ve acceptance harness."
        case .vFinal:
            return "Eternal seal, mastery terminali ve hyper-automation omurgasi."
        case .vOmega:
            return "Omega failover, physical anchor, black card ve legacy protokolu."
        }
    }
}

public enum SimulationSourceKind: String, CaseIterable, Hashable {
    case swift
    case python
    case rust
    case go
    case dataform
    case crossplane
    case shell
    case markdown
    case yaml

    public var badge: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .rust: return "Rust"
        case .go: return "Go"
        case .dataform: return "Dataform"
        case .crossplane: return "Crossplane"
        case .shell: return "Shell"
        case .markdown: return "Markdown"
        case .yaml: return "YAML"
        }
    }

    public var tint: Color {
        switch self {
        case .swift: return QAITheme.panelBlue
        case .python: return QAITheme.success
        case .rust: return QAITheme.warning
        case .go: return Color.cyan
        case .dataform: return Color.teal
        case .crossplane: return Color.indigo
        case .shell: return Color.orange
        case .markdown: return QAITheme.textSecondary
        case .yaml: return Color.mint
        }
    }
}

public enum SimulationIntegrationMode: String, Hashable {
    case nativeSwift
    case swiftPort
    case workflowMirror

    public var title: String {
        switch self {
        case .nativeSwift:
            return "Native"
        case .swiftPort:
            return "Swift Port"
        case .workflowMirror:
            return "Workflow Mirror"
        }
    }

    public var detail: String {
        switch self {
        case .nativeSwift:
            return "Bu katman dogrudan QuantumAIMobile icinde derleniyor."
        case .swiftPort:
            return "Dis dildeki prototype, build-safe Swift akisina tasindi."
        case .workflowMirror:
            return "CLI/IaC/Dataform akisları iOS target icin Swift runtime temsilcisine cevrildi."
        }
    }
}

public struct SimulationModule: Identifiable, Hashable {
    public let version: SimulationVersion
    public let slug: String
    public let title: String
    public let summary: String
    public let sourceKinds: [SimulationSourceKind]
    public let integrationMode: SimulationIntegrationMode
    public let originHint: String
    public let capabilities: [String]

    public var id: String { "\(version.rawValue)-\(slug)" }
}

public struct SimulationVersionBundle: Identifiable, Hashable {
    public let version: SimulationVersion
    public let codename: String
    public let overview: String
    public let modules: [SimulationModule]

    public var id: SimulationVersion { version }
    public var compiledModuleCount: Int { modules.count }
    public var portedModuleCount: Int {
        modules.filter { $0.integrationMode != .nativeSwift }.count
    }
}

public enum SimulationCatalog {
    public static let all: [SimulationVersionBundle] = [
        bundle(
            .v3,
            codename: "Core Expansion",
            overview: "Ana repo icindeki pipeline, dashboard, partner ve property katmanlarinin derlenebilir toplami.",
            modules: [
                module(.v3, slug: "mega-pipeline", title: "Mega Pipeline Router", summary: "Kucuk ve buyuk islemleri ayirip telemetriye baglayan v3 veri boru hatti.", sourceKinds: [.swift, .python], integrationMode: .swiftPort, originHint: "SyncKit/MegaPipelineRouter.swift + core/pipeline/mega_pipeline_router.py", capabilities: ["Risk queue fork", "Micro batch routing", "HQ telemetry sync"]),
                module(.v3, slug: "wealth-engine", title: "Mega Computation Engine", summary: "10$ -> 1M$ servet senaryolarini paralel hesaplama modeliyle yurutur.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "CoreKit/MegaComputationEngine.swift", capabilities: ["Monte Carlo pathing", "Probability stream", "Profit telemetry"]),
                module(.v3, slug: "saas-layer", title: "SaaS & Partner Surface", summary: "Gateway, partner branding ve white-label panel akislarini tek yuzde toplar.", sourceKinds: [.swift, .python], integrationMode: .swiftPort, originHint: "CoreKit/PartnerBrandingEngine.swift + core/gateway/bursa_gateway.py", capabilities: ["Partner tier registry", "Theme switching", "Gateway state mirror"]),
                module(.v3, slug: "property-genesis", title: "Property & Genesis", summary: "Mulk haritalama, passive income sync ve genesis node durumlarini izler.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "PropertyKit/Bursa3DMapEngine.swift + AppShell/GenesisNodeView.swift", capabilities: ["3D vault sync", "Passive income heartbeat", "Node uptime tracking"])
            ]
        ),
        bundle(
            .v4,
            codename: "Adaptive Autopilot",
            overview: "v4 alpha prototiplerinin otonom AI, DeFi ve governance kabiliyetlerini Swift target icinde toplar.",
            modules: [
                module(.v4, slug: "autopilot", title: "Self-Learning Autopilot", summary: "Kayip desenlerinden ogrenip sonraki aksiyonu guncelleyen AI katmani.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "../QuantumAI-Dockerized-System.v4.alpha/core/autopilot/strategy_evolver.py", capabilities: ["Loss learning", "Pattern defense", "Adaptive strategy memory"]),
                module(.v4, slug: "defi", title: "Liquidity Snatcher & Guard", summary: "Arbitraj ve slippage savunmasini ayni v4 akisinda birlestirir.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "liquidity_snatcher.py + LiquidityGuard.swift", capabilities: ["Opportunity scoring", "Flash swap dry run", "Slippage validation"]),
                module(.v4, slug: "economy", title: "Dynamic Burn & Synergy", summary: "Token burn, metaverse registry ve neural map fusion akisini temsil eder.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "dynamic_burn_engine.py + BursaNeuralMapFusion.swift", capabilities: ["Supply burn model", "Asset synergy gauge", "Cross-reality registry"]),
                module(.v4, slug: "governance", title: "DAO Governance & Healer", summary: "Hazine dagitimi ve self-healing altyapi prototiplerini tek build-safe yuzde birlestirir.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "governance_oracle.py + v4_healer.py + MainnetPulse.swift", capabilities: ["Treasury split", "Incident hotfix mirror", "Pulse loop"])
            ]
        ),
        bundle(
            .v5,
            codename: "HFT Sovereign",
            overview: "HFT, CBDC ve kuantum ajan katmanlarini QuantumAIMobile icinde derlenebilir runtime sinyallerine tasir.",
            modules: [
                module(.v5, slug: "hft-core", title: "Rust HFT Core Mirror", summary: "Matcher, latency benchmark ve p99 izini Swift target icin port edilen runtime kartina yansitir.", sourceKinds: [.rust, .swift], integrationMode: .swiftPort, originHint: "../QuantumAI-HFT-Core/src/fast_path/matcher.rs + benches/latency_test.rs", capabilities: ["Fast-path catalog", "Latency badge", "Tick-to-trade monitoring"]),
                module(.v5, slug: "cbdc", title: "TRYC Liquidity Stack", summary: "TCMB bridge, reserve monitor ve CBDC allocation akislarini derlenen iOS modulu olarak temsil eder.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "tcmb_bridge.py + ignite_tryc_transfer.py + TRYCManager.swift", capabilities: ["Reserve tracking", "Transfer gating", "Compliance status"]),
                module(.v5, slug: "quantum-agent", title: "Quantum RL Trader", summary: "PennyLane/qiskit dusuncesini build-safe ajan guven skoru halinde uygulamaya tasir.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "quantum_agent_v5.py + QuantumTerminalView.swift", capabilities: ["Confidence scoring", "Action badge", "Dry-run decisioning"]),
                module(.v5, slug: "sovereign-command", title: "Galactic & Sovereign Command", summary: "Galactic control, final seal ve command center katmanlarini tek kartta toplar.", sourceKinds: [.swift, .python], integrationMode: .swiftPort, originHint: "GalacticControlView.swift + orbital_sealer.py + FinalSovereignSeal.swift", capabilities: ["Orbital sync status", "Seal activation", "Global throughput mirror"])
            ]
        ),
        bundle(
            .v6,
            codename: "Interstellar Pulse",
            overview: "Pulse sealer, lazer link ve audit vault akislari interstellar runtime katmani olarak yeniden derlenir.",
            modules: [
                module(.v6, slug: "time-vault", title: "Nanosecond Pulse Sealer", summary: "PTP v2.1 hassasiyet vizyonunu Swift target icinde pulse timing metriğine donusturur.", sourceKinds: [.rust, .swift], integrationMode: .swiftPort, originHint: "../QuantumAI-Interstellar-Core/src/time_vault/sealer.rs", capabilities: ["Pulse seal ID", "Drift mirror", "Atomic timestamp status"]),
                module(.v6, slug: "laser-link", title: "Interstellar Data Bridge", summary: "Uydu lazer link simülasyonunu app icindeki galaktik senkronizasyon kartina tasir.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "core/interstellar/laser_link.py + PulseMonitorView.swift", capabilities: ["Link strength", "Emission log", "Pulse routing"]),
                module(.v6, slug: "compliance", title: "Galactic Compliance", summary: "Travel-rule, audit evidence ve archive sealer akislarini build-safe denetim modulu yapar.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "v6_auditor_ai.py + GalacticCompliance.swift + BlackHoleVault.swift", capabilities: ["Audit-ready report", "Archive seal", "Cross-border certification"]),
                module(.v6, slug: "final-view", title: "Interstellar Sovereignty", summary: "v6 final dashboard ve archival durumlarini tek bir app katmaninda izler.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "PulseMonitorView.swift + InterstellarFinalView.swift", capabilities: ["Sovereignty meter", "Archive integrity", "Launch status"])
            ]
        ),
        bundle(
            .v7,
            codename: "Singularity Bridge",
            overview: "Singularity, neural governance, isolation ve global command katmanlarini ortak target'ta derler.",
            modules: [
                module(.v7, slug: "mesh", title: "Global Asset Mesh", summary: "Bursa varliklari ile dijital likiditeyi neural mesh seklinde baglar.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "../QuantumAI-Singularity-Core/core/economy/mesh/global_asset_mesh.py", capabilities: ["Mesh efficiency", "Asset bridge", "Synergy score"]),
                module(.v7, slug: "governance", title: "Neural Governance", summary: "Stres analizi, veto korumasi ve quantum silence aksiyonlarini uygular.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "CoreKitV7/Governance/NeuralGovernance.swift + Silence/AmiralSilence.swift", capabilities: ["Decision atmosphere", "Absolute zero prep", "Sovereign lock"]),
                module(.v7, slug: "isolation", title: "Absolute Zero & Orbital Seed", summary: "Saldiri aninda izolasyon ve orbital seed senkronunu tek runtime kontrol merkezine toplar.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "absolute_zero.py + OrbitalSeed.swift + IsolationControlView.swift", capabilities: ["Isolation mode", "Uplink mirror", "Seed orbit status"]),
                module(.v7, slug: "command", title: "Neural Command Surface", summary: "Neural logs, global command ve sovereign throne akislarini derlenen app paneline baglar.", sourceKinds: [.swift, .python], integrationMode: .swiftPort, originHint: "NeuralCommandView.swift + SovereignThroneView.swift + bursa_constitution.py", capabilities: ["Thought stream", "Constitution state", "Global action rail"])
            ]
        ),
        bundle(
            .v8,
            codename: "FinOps Expansion",
            overview: "Dataform, Crossplane, onboarding CLI ve smoke harness akislari iOS uyumlu workflow temsilcilerine cevrilir.",
            modules: [
                module(.v8, slug: "finops", title: "FinOps Warehouse Mirror", summary: "Dataform/BigQuery maliyet matrisini Swift runtime kanit ozetine cevirir.", sourceKinds: [.dataform, .swift], integrationMode: .workflowMirror, originHint: "dataform-finops/definitions/bq_commitments.sqlx", capabilities: ["Cost ledger summary", "Net gain projection", "Warehouse readiness"]),
                module(.v8, slug: "qkd", title: "Crossplane QKD Claim", summary: "xqkdlink claim'i iOS icinde altyapi hazirlik ve composition durumu olarak temsil edilir.", sourceKinds: [.crossplane, .yaml, .swift], integrationMode: .workflowMirror, originHint: "compositions/xqkdlink.yaml", capabilities: ["Link claim mirror", "Encryption profile", "Readiness state"]),
                module(.v8, slug: "onboarding", title: "Self-Service Onboarding", summary: "Go CLI onboarding akisi uygulama icinde partner bootstrap runbook'una cevrilir.", sourceKinds: [.go, .swift], integrationMode: .workflowMirror, originHint: "cmd/acme-onboard/main.go", capabilities: ["Namespace checklist", "Grafana contact workflow", "Slack channel plan"]),
                module(.v8, slug: "acceptance", title: "Acceptance Harness", summary: "Smoke test ve evidence paket akisini app'te sabah denetim ozetine dönüştürür.", sourceKinds: [.shell, .markdown, .swift], integrationMode: .workflowMirror, originHint: "smoke-test + evidence.sh + soc2-index.md", capabilities: ["Evidence status", "Smoke checklist", "Audit cadence"])
            ]
        ),
        bundle(
            .vFinal,
            codename: "Sovereign Terminal",
            overview: "vFinal hyper-automation, eternal ledger ve mastery terminali ortak compiled katmanda yasar.",
            modules: [
                module(.vFinal, slug: "ghost", title: "Ghost Hyper-Automation", summary: "Uzun dongulu otonom strateji zihnini kontrollu iOS runtime eventlerine cevirir.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "core/automation/ghost/ghost_engine.py", capabilities: ["Auto-heal heartbeat", "Consciousness index", "Loop cadence"]),
                module(.vFinal, slug: "eternal-ledger", title: "Eternal Ledger", summary: "Ebedi muhurlenmis varlik durumunu uygulama icinde audit-safe olarak saklar.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "CoreKitFinal/Eternal/EternalLedger.swift", capabilities: ["Seal fingerprint", "Sovereign flag", "Archive relay"]),
                module(.vFinal, slug: "mastery", title: "Mastery Terminal", summary: "vFinal dashboard vizyonunu tek ekranda crown, pulse ve sovereignty durumu olarak sunar.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "AppShellFinal/MasteryView.swift", capabilities: ["Pulse marker", "Health banner", "Crown state"]),
                module(.vFinal, slug: "automation-runbook", title: "Final Automation Runbook", summary: "QKD, launch ve immutable workflow'lari iOS tarafinda tek summary pipeline olarak toplar.", sourceKinds: [.shell, .swift], integrationMode: .workflowMirror, originHint: "omega_launch.sh + operational prompts", capabilities: ["Launch stage mirror", "Command checklist", "Integrated readiness"])
            ]
        ),
        bundle(
            .vOmega,
            codename: "Omega Event",
            overview: "Omega mesh failover, vault, black card, physical anchor ve legacy protokollerini tek hedefte toplar.",
            modules: [
                module(.vOmega, slug: "mesh-reconstitution", title: "Omega Mesh Reconstitution", summary: "Failover ve mikro-servis topolojisi yenilemesini build-safe runtime olayına taşır.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "mesh_reconstitutor.py + omega_launch.sh", capabilities: ["Failover node", "Orbital migration", "Mesh health"]),
                module(.vOmega, slug: "omega-vault", title: "Omega Wealth Vault", summary: "Omega vault ile beyond-reach varlik muhru uygulama seviyesinde izlenir.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "CoreKitFinal/Omega/OmegaVault.swift", capabilities: ["Vault seal", "Last sync", "Asset lock summary"]),
                module(.vOmega, slug: "physical-anchor", title: "Physical Anchor & Black Card", summary: "Bina altyapisi ve Amiral Black Card akislarini tek kartta optimize eder.", sourceKinds: [.python, .swift], integrationMode: .swiftPort, originHint: "osmangazi_iot.py + AppShellFinal/BlackCard/AmiralBlackCardView.swift", capabilities: ["Thermal regulation mirror", "Liquidity balance", "Physical grid status"]),
                module(.vOmega, slug: "legacy", title: "Legacy Protocol", summary: "Varis protokolunu ve mutlak kasayi zaman asimina karsi korur.", sourceKinds: [.swift], integrationMode: .nativeSwift, originHint: "CoreKitFinal/Legacy/HeirProtocol.swift", capabilities: ["Heartbeat timeout", "Succession seal", "Bloodline security"])
            ]
        )
    ]

    public static var totalModuleCount: Int {
        all.reduce(0) { $0 + $1.modules.count }
    }

    public static var totalPortedCount: Int {
        all.reduce(0) { $0 + $1.portedModuleCount }
    }

    public static func bundle(for version: SimulationVersion) -> SimulationVersionBundle {
        all.first(where: { $0.version == version }) ?? all[0]
    }

    private static func bundle(
        _ version: SimulationVersion,
        codename: String,
        overview: String,
        modules: [SimulationModule]
    ) -> SimulationVersionBundle {
        SimulationVersionBundle(version: version, codename: codename, overview: overview, modules: modules)
    }

    private static func module(
        _ version: SimulationVersion,
        slug: String,
        title: String,
        summary: String,
        sourceKinds: [SimulationSourceKind],
        integrationMode: SimulationIntegrationMode,
        originHint: String,
        capabilities: [String]
    ) -> SimulationModule {
        SimulationModule(
            version: version,
            slug: slug,
            title: title,
            summary: summary,
            sourceKinds: sourceKinds,
            integrationMode: integrationMode,
            originHint: originHint,
            capabilities: capabilities
        )
    }
}
