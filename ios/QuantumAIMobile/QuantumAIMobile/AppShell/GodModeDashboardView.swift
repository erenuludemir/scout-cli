import SwiftUI

public struct GodModeDashboardView: View {
    @State private var sniperActive = true
    @State private var calls = ["BSC: $QAI Call", "ETH: Bursa Whale Entry"]

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Circle()
                    .fill(sniperActive ? QAITheme.success : QAITheme.error)
                    .frame(width: 10, height: 10)
                Text("GOD MODE: \(sniperActive ? "AVCI" : "BEKLEMEDE")")
                    .font(.caption)
                    .bold()
                Spacer()
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(QAITheme.accent)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("CALL CHANNELS AI ANALIZ")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                ForEach(calls, id: \.self) { call in
                    HStack {
                        Image(systemName: "megaphone.fill")
                            .font(.caption2)
                        Text(call)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Text("BULLISH")
                            .foregroundStyle(QAITheme.success)
                            .font(.system(size: 9))
                            .bold()
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                VStack(alignment: .leading) {
                    Text("SNIPER SLIPPAGE")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("%15.0")
                        .font(.headline)
                        .foregroundStyle(QAITheme.textPrimary)
                }
                Spacer()
                Button("SIMULE ET") {
                    WealthPipeline.shared.simulateWealthPath()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
    }
}
