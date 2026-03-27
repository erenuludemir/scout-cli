import SwiftUI

public struct StressMonitorView: View {
    @State private var healthScore = 0.98
    @State private var liveTraffic = true
    @State private var lastSimResult = "Sarsilmaz"

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("SISTEM DAYANIKLILIK SKORU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                    .bold()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: healthScore)
                        .stroke(QAITheme.success, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("%\(Int(healthScore * 100))")
                        .font(.title)
                        .bold()
                        .monospaced()
                }
                .frame(width: 120, height: 120)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                VStack(alignment: .leading) {
                    Text("SON SIMULASYON")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text(lastSimResult)
                        .font(.headline)
                        .foregroundStyle(QAITheme.panelBlue)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(QAITheme.panelBlue)
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Label("MAINNET SYNC: AKTIF (DRY RUN)", systemImage: "bolt.fill")
                Spacer()
                Circle()
                    .fill(liveTraffic ? QAITheme.success : QAITheme.error)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .font(.caption)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            PrimaryButton(title: "Stres Telemetrisini Yenile") {
                healthScore = Double.random(in: 0.84...0.99)
                lastSimResult = healthScore > 0.9 ? "Sarsilmaz" : "Dikkat Gerekli"
            }
        }
        .padding()
        .navigationTitle("Stress Monitor")
    }
}
