import SwiftUI

public struct QuantumComparisonView: View {
    @State private var perfClassic = 95.0
    @State private var perfQuantum = 12.0

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("GUVENLIK VE PERFORMANS ANALIZI")
                .font(.caption)
                .bold()
                .foregroundStyle(QAITheme.textSecondary)

            HStack {
                VStack {
                    Text("Klasik")
                        .font(.caption2)
                    Capsule()
                        .fill(QAITheme.success)
                        .frame(width: 40, height: perfClassic)
                    Text("1 Gbps")
                        .font(.system(size: 8))
                }
                Spacer()
                VStack {
                    Text("QKD")
                        .font(.caption2)
                    Capsule()
                        .fill(QAITheme.panelBlue)
                        .frame(width: 40, height: perfQuantum)
                    Text("12 Kbps")
                        .font(.system(size: 8))
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                comparisonRow("AI Oracle Dogruluk", value: "%92.8", tint: QAITheme.panelBlue)
                comparisonRow("Hata Duzeltme (NISQ)", value: "Noisy", tint: .orange)
                comparisonRow("AES-256", value: CryptoMetricAnalyzer.shared.evaluateThreat(algorithm: "AES", keySize: 256) == .none ? "OK" : "RISK", tint: QAITheme.success)
                comparisonRow("RSA-2048", value: "CRITICAL", tint: QAITheme.error)
            }
            .padding()
            .background(QAITheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
    }

    private func comparisonRow(_ title: String, value: String, tint: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(tint)
                .bold()
        }
        .font(.footnote)
    }
}
