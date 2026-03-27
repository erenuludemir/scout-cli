import SwiftUI

public struct RuntimeMetricsCard: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Runtime Metrics", systemImage: "waveform.path.ecg")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(QAITheme.textPrimary)
                    Spacer()
                    Text(Date.now.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(QAITheme.textSecondary)
                }

                HStack(spacing: 10) {
                    metric(title: "Launch", value: env.runtimeMetrics.launches, accent: QAITheme.accent)
                    metric(title: "Live Ticks", value: env.runtimeMetrics.liveTicks, accent: QAITheme.panelBlue)
                    metric(title: "Sim Ticks", value: env.runtimeMetrics.simTicks, accent: QAITheme.success)
                }

                HStack(spacing: 10) {
                    metric(title: "WS Reconnect", value: env.runtimeMetrics.wsReconnects, accent: QAITheme.warning)
                    metric(title: "REST Fallback", value: env.runtimeMetrics.restFallbacks, accent: QAITheme.textSecondary)
                }
            }
        }
    }

    private func metric(title: String, value: Int, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(QAITheme.textSecondary)
            Text("\(value)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(QAITheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
