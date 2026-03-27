import SwiftUI

public struct MegaPipelineView: View {
    @ObservedObject private var computation = MegaComputationEngine.shared
    @ObservedObject private var batchProcessor = MegaBatchProcessor.shared
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan

    @State private var ingestionRate = 850
    @State private var pipelineLoad = 0.42

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("PIPELINE CANLI YUKU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: pipelineLoad)
                        .stroke(QAITheme.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(ingestionRate) TX/S")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .frame(width: 88, height: 88)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("SERVET SENARYO ANALIZI")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(QAITheme.panelBlue)
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .foregroundStyle(QAITheme.panelBlue)
                    Text("10$ -> 1M$ hedef olasiligi")
                    Spacer()
                    Text("%\(String(format: "%.2f", computation.lastProbability))")
                        .bold()
                        .foregroundStyle(QAITheme.success)
                }
                .font(.system(size: 11, design: .monospaced))

                PrimaryButton(title: computation.isRunning ? "Simulasyon Calisiyor" : "Simulasyonu Baslat") {
                    computation.simulateWealthGrowth()
                }
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Label("AGGREGATOR: AKTIF", systemImage: "tray.2.fill")
                Spacer()
                Text("Batch: 100")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let latest = sinir.telemetryLog.first {
                Text(latest)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(QAITheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .navigationTitle("Mega Pipeline")
        .onAppear {
            ingestionRate = Int.random(in: 720...980)
            pipelineLoad = Double.random(in: 0.28...0.62)
            let sample = Order(
                id: UUID().uuidString.prefix(8).lowercased(),
                symbol: "BTCUSDT",
                side: "BUY",
                price: 64_500,
                amount: 12,
                timestamp: .now
            )
            batchProcessor.queueOrder(sample)
        }
    }
}
