import SwiftUI

public struct GodModeControlView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var mempoolActive = true
    @State private var radarLogs = [
        "[09:21:01] Mempool: Large Swap Detected",
        "[09:21:05] Radar: Liquidity Locked on PancakeSwap"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("GOD MODE RADAR")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(QAITheme.error)
                    Text(mempoolActive ? "SENSORLER: CEVRIMICI" : "SENSORLER: KAPALI")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(mempoolActive ? QAITheme.success : QAITheme.error)
                }
                Spacer()
                Toggle("", isOn: $mempoolActive)
                    .labelsHidden()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("COPY TRADE AYARLARI")
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack {
                    Text("Kopyalama Orani: %\(Int(env.copyTrade.copyRatio * 100))")
                    Slider(
                        value: Binding(
                            get: { env.copyTrade.copyRatio },
                            set: { env.copyTrade.copyRatio = $0 }
                        ),
                        in: 0.01 ... 1.0
                    )
                }
            }
            .padding()
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("RADAR TELEMETRI LOGLARI")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(radarLogs, id: \.self) { log in
                            Text(log)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                .frame(height: 100)
            }
            .padding()
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding()
    }
}
