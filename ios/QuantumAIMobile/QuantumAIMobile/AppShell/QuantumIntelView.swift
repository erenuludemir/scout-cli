import SwiftUI

public struct QuantumIntelView: View {
    @State private var bapAccuracy = 0.928
    @State private var entropyPulse = false
    @State private var qkdStatus = "ESTABLISHED"

    public init() {}

    public var body: some View {
        VStack(spacing: 25) {
            VStack {
                HStack {
                    Text("QNN BIT ACCURACY (BAP)")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Spacer()
                    Text("%92.8")
                        .foregroundStyle(QAITheme.panelBlue)
                        .bold()
                }
                ProgressView(value: bapAccuracy)
                    .tint(QAITheme.panelBlue)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Image(systemName: "atom")
                    .foregroundStyle(QAITheme.success)
                    .rotationEffect(.degrees(entropyPulse ? 360 : 0))
                    .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: entropyPulse)

                VStack(alignment: .leading) {
                    Text("QRNG SOURCE: ACTIVE")
                        .font(.caption)
                        .bold()
                    Text("QKD Status: \(qkdStatus)")
                        .font(.system(size: 8))
                }
                Spacer()
                Circle()
                    .fill(QAITheme.success)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .background(QAITheme.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                entropyPulse = true
                qkdStatus = QuantumSecurityProvider.shared.initiateQKDExchange().status
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("POST-QUANTUM STANDARDS")
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack {
                    QuantumIntelBadge(text: "Kyber-768", color: QAITheme.panelBlue)
                    QuantumIntelBadge(text: "Dilithium", color: .purple)
                    QuantumIntelBadge(text: "SPHINCS+", color: .orange)
                }
            }
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct QuantumIntelBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(6)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
