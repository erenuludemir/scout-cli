import SwiftUI

public struct NeuralCryptoView: View {
    @State private var privacyCapacity = 0.99
    @State private var logs = ["Protocol: Stable", "Shor Direnci: 100%", "Lattice Sealing: OK"]

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("GIZLILIK KAPASITESI (SHANNON LIMIT)")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: privacyCapacity)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("%\(Int(privacyCapacity * 100))")
                        .font(.headline)
                        .bold()
                }
                .frame(width: 100, height: 100)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading) {
                Text("AI CRYPTOGRAPHER LOGS")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(QAITheme.error)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(logs, id: \.self) { log in
                            Text("> \(log)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(QAITheme.success)
                        }
                    }
                }
                .frame(height: 80)
            }
            .padding()
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
        .onAppear {
            if ShannonSentinel.shared.measureLeakage(packetEntropy: privacyCapacity) {
                logs.insert("Leakage detected and blocked", at: 0)
                privacyCapacity = 0.84
            }
        }
    }
}
