import SwiftUI

public struct HQAdminView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan
    @ObservedObject private var wealthBridge = WealthBridge.shared
    @ObservedObject private var simulations = SimulationControlCenter.shared
    @State private var serverLogs: [String] = ["System Init", "Redpanda Online", "AI Oracle Connected"]
    
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("AI ORACLE (30S)") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BULLISH %92")
                                .font(.headline)
                                .foregroundStyle(QAITheme.success)
                            Text("Ornek sinyal penceresi")
                                .font(.caption)
                                .foregroundStyle(QAITheme.textSecondary)
                        }
                        Spacer()
                        BursaHQLogo()
                            .frame(width: 36, height: 36)
                    }

                    ForEach(Array(serverLogs.enumerated()), id: \.offset) { _, entry in
                        Text("[\(Date().formatted(.dateTime.hour().minute().second()))] \(entry)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(QAITheme.success)
                    }
                }

                Section("GÜVENLİK (SENTINEL)") {
                    HStack {
                        Image(systemName: "shield.checkered").foregroundColor(.green)
                        Text("Siber Kalkan: AKTİF")
                        Spacer()
                        Text("\(sinir.blockedIPCount) BLOKE").monospaced()
                    }
                }
                
                Section("SİSTEM DURUMU") {
                    LabeledContent("Senkronizasyon", value: sinir.hqBaglantiDurumu ? "Online" : "Offline")
                    if let son = sinir.sonSenkronizasyon {
                        LabeledContent("Son Veri", value: son.formatted(.dateTime.hour().minute().second()))
                    }
                }

                Section("AG & VAULT") {
                    NetworkMonitorView()
                        .listRowInsets(EdgeInsets())
                }

                Section("NEURO VISOR") {
                    NeuroVisorView()
                        .listRowInsets(EdgeInsets())
                }

                Section("HEALING & PENTEST") {
                    SystemHealthView()
                        .listRowInsets(EdgeInsets())
                }

                Section("COMPLIANCE & TRANSFER") {
                    SecurityMonitorView()
                        .listRowInsets(EdgeInsets())
                    LabeledContent("Wealth Bridge", value: wealthBridge.statusText)
                    if let amount = wealthBridge.lastTransferredAmount {
                        LabeledContent("Son Transfer", value: "$\(amount.formatted(.number.precision(.fractionLength(2))))")
                    }
                }

                Section("QUANTUM INTELLIGENCE") {
                    QuantumIntelView()
                        .listRowInsets(EdgeInsets())
                    NavigationLink("Quantum Ops Terminal") {
                        QuantumPerformanceDashboard(showsBackButton: true)
                            .navigationTitle("Quantum Ops")
                    }
                    NavigationLink("Quantum Comparison") {
                        QuantumComparisonView()
                            .navigationTitle("Quantum Comparison")
                    }
                    NavigationLink("Neural Crypto") {
                        NeuralCryptoView()
                            .navigationTitle("Neural Crypto")
                    }
                }

                Section("IGNITION & COMMAND") {
                    IgnitionStatusView()
                        .listRowInsets(EdgeInsets())
                    NavigationLink("Command Center") {
                        CommandCenterView()
                    }
                    NavigationLink("Mainnet Control (Dry Run)") {
                        MainnetCommandView()
                    }
                }

                Section("SON TELEMETRI") {
                    if sinir.telemetryLog.isEmpty {
                        Text("Henuz telemetri yok")
                            .foregroundStyle(QAITheme.textSecondary)
                    } else {
                        ForEach(Array(sinir.telemetryLog.prefix(6).enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }

                Section("SIMULATION STACK") {
                    LabeledContent("Aktif Hedef", value: simulations.selectedVersion.displayName)
                    LabeledContent("Compiled Modül", value: "\(simulations.totalModuleCount)")
                    NavigationLink("Version Matrix Hub") {
                        SimulationsHubView()
                    }
                }

                Section("PARTNERLER") {
                    HStack {
                        Label("Bursa_Invest_01", systemImage: "person.2.fill")
                        Spacer()
                        Text("ON-LINE")
                            .font(.caption)
                            .foregroundStyle(QAITheme.success)
                    }
                }

                Section("GOD MODE") {
                    NavigationLink("God Mode Dashboard") {
                        GodModeDashboardView()
                    }
                    NavigationLink("God Mode Control") {
                        GodModeControlView()
                    }
                }

                Section("WHALE & ON-CHAIN") {
                    NavigationLink("Whale Radar") {
                        WhaleRadarView()
                    }
                }

                Section("AI & GRID") {
                    NavigationLink("AI Training Hub") {
                        AITrainingView()
                    }
                    NavigationLink("Grid Bot Monitor") {
                        GridBotMonitorView()
                    }
                }

                Section("COMPLIANCE & STACK") {
                    NavigationLink("Compliance Monitor") {
                        ComplianceMonitorView()
                    }
                    NavigationLink("Tech Stack Monitor") {
                        TechStackView()
                    }
                }

                Section("PIPELINE & STRESS") {
                    NavigationLink("Mega Pipeline") {
                        MegaPipelineView()
                    }
                    NavigationLink("Stress Analysis") {
                        StressMonitorView()
                    }
                }

                Section("SAAS & PARTNERS") {
                    NavigationLink("SaaS Dashboard") {
                        SaaSDashboardView()
                    }
                    NavigationLink("Partner Command") {
                        PartnerCommandView()
                    }
                }

                Section("PROPERTY & GENESIS") {
                    NavigationLink("Property Ignition") {
                        PropertyIgnitionView()
                    }
                    NavigationLink("Genesis Node") {
                        GenesisNodeView()
                    }
                }
            }
            .navigationTitle("Bursa HQ Admin")
        }
    }
}
