import SwiftUI

public struct GridBotMonitorView: View {
    @State private var activeGrids = 12
    @State private var totalProfit = 124.50
    @State private var leverage = 10

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("ACTIVE GRID BOT")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("\(activeGrids) Kademeli Izgara")
                        .font(.headline)
                }
                Spacer()
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(QAITheme.panelBlue)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                VStack(alignment: .leading) {
                    Text("GRID PROFIT")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("+$\(String(format: "%.2f", totalProfit))")
                        .foregroundStyle(QAITheme.success)
                        .bold()
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(QAITheme.success)
            }
            .padding()
            .background(QAITheme.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack {
                HStack {
                    Text("KALDIRAC: \(leverage)X")
                        .font(.caption2)
                        .bold()
                    Spacer()
                    Text("RISK: DUSUK")
                        .foregroundStyle(QAITheme.success)
                        .font(.system(size: 8))
                }
                ProgressView(value: 0.2)
                    .tint(QAITheme.success)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                MarginGuard.shared.evaluateRisk(currentPrice: 50_000, liquidationPrice: 47_800, leverage: leverage)
            }
        }
        .padding()
    }
}
