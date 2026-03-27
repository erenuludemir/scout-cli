import SwiftUI

public struct AITrainingView: View {
    @State private var trainingProgress = 0.74
    @State private var modelAccuracy = 0.928
    @State private var activeSignals = ["BTC/USDT BUY - %89 Guven", "ETH/USDT HOLD - %62 Guven"]

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("ONLINE LEARNING DURUMU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(QAITheme.error)
                    Text("Model periyodik guncelleniyor")
                        .font(.caption)
                        .bold()
                    Spacer()
                    Text("%\(Int(trainingProgress * 100))")
                        .font(.system(size: 10, design: .monospaced))
                }
                ProgressView(value: trainingProgress)
                    .tint(QAITheme.error)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("SINYAL ANALIZ GEREKCELERI")
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(activeSignals, id: \.self) { signal in
                            HStack {
                                Circle()
                                    .fill(signal.contains("BUY") ? QAITheme.success : .orange)
                                    .frame(width: 8, height: 8)
                                Text(signal)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 80)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                VStack(alignment: .leading) {
                    Text("AGENT REWARD SCORE")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("+1,240.50 PNL")
                        .foregroundStyle(QAITheme.success)
                        .bold()
                }
                Spacer()
                Text("%\(Int(modelAccuracy * 1000) / 10)")
                    .font(.caption)
                    .foregroundStyle(QAITheme.panelBlue)
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
    }
}
