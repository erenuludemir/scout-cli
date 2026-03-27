import SwiftUI

public struct GenesisNodeView: View {
    @ObservedObject private var eternalLoop = EternalLoopEngine.shared
    @State private var nodeID = "BURSA-HQ-EBEDI"

    public init() {}

    public var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [QAITheme.accent, QAITheme.panelBlue],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: QAITheme.accent.opacity(0.4), radius: 10)

                VStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.white)
                    Text("GENESIS NODE")
                        .font(.system(size: 10, weight: .black))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                GenesisInfoRow(label: "Node ID", value: nodeID)
                GenesisInfoRow(label: "Kuantum Muhru", value: "SEALED_v3")
                GenesisInfoRow(label: "Otonom Rejim", value: eternalLoop.isRunning ? "AKTIF" : "BEKLEMEDE")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            HStack {
                Image(systemName: "infinity")
                    .foregroundStyle(QAITheme.success)
                Text("DONGU CALISMA SURESI:")
                    .font(.caption2)
                Spacer()
                Text("\(eternalLoop.uptimeSeconds)s")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .padding()

            PrimaryButton(title: eternalLoop.isRunning ? "Loop Aktif" : "Loop Baslat") {
                eternalLoop.initiateEternalLoop()
            }
        }
        .padding()
        .navigationTitle("System Genesis")
        .onAppear {
            eternalLoop.initiateEternalLoop()
        }
    }
}

private struct GenesisInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(QAITheme.textSecondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.caption)
    }
}
