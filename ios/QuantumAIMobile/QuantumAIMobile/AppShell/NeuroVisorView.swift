import SwiftUI

public struct NeuroVisorView: View {
    @ObservedObject private var visor = NeuroVisorEngine.shared
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(QAITheme.success.opacity(0.2), lineWidth: 1)
                Circle()
                    .stroke(QAITheme.success.opacity(0.12), lineWidth: 1)
                    .scaleEffect(0.72)

                VStack(spacing: 4) {
                    Text("\(visor.redpandaThroughput)")
                        .font(.system(.title2, design: .monospaced))
                        .bold()
                    Text("MSG / SEC")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
            .frame(height: 150)
            .overlay(
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(QAITheme.success)
                    .font(.largeTitle)
                    .opacity(0.3)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("AKTIF SAVUNMA HATLARI")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(QAITheme.textSecondary)
                metricRow("Honeypot Quarantine", status: "DRY-RUN", tint: QAITheme.accent)
                metricRow("Rate-Limit Trap", status: "AKTIF", tint: QAITheme.panelBlue)
                metricRow("Blocked IP", status: "\(sinir.blockedIPCount)", tint: QAITheme.error)
                metricRow("Neural Health", status: "%\(Int(visor.neuralSynapseHealth * 100))", tint: QAITheme.success)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricRow(_ title: String, status: String, tint: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .font(.caption2)
                .foregroundStyle(tint)
        }
    }
}
