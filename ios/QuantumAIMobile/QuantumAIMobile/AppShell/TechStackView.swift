import SwiftUI

public struct TechStackView: View {
    @State private var web3Status = true
    @State private var quantumWires = 4
    @State private var apiLatency = 14

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("FASTAPI CORE")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("Gecikme: \(apiLatency)ms")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                Spacer()
                Circle()
                    .fill(web3Status ? QAITheme.success : QAITheme.error)
                    .frame(width: 10, height: 10)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("QUANTUM CIRCUIT")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack(spacing: 15) {
                    ForEach(0..<quantumWires, id: \.self) { i in
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(QAITheme.panelBlue)
                                .frame(width: 4, height: 40)
                            Text("Q\(i)")
                                .font(.system(size: 8))
                        }
                    }
                    Spacer()
                    Text("Hibrit Mod: Aktif")
                        .font(.caption)
                        .foregroundStyle(QAITheme.panelBlue)
                }
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.orange)
                Text("WEB3 MAINNET SYNC")
                    .font(.caption)
                    .bold()
                Spacer()
                Text("Blok: #1945231")
                    .font(.system(size: 10, design: .monospaced))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                BursaNetworkEngine.shared.processApplePay(amount: 42)
            }
        }
        .padding()
    }
}
