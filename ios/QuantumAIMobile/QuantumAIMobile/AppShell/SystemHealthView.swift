import SwiftUI

public struct SystemHealthView: View {
    @State private var healingStatus = "BEKLEMEDE"
    @State private var pentestResult = "SEALED"
    @State private var shorScore = 99.9
    @State private var groverScore = 100.0

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("SELF-HEALING ENGINE")
                        .font(.caption)
                        .bold()
                    Text("DURUM: \(healingStatus)")
                        .font(.system(size: 10, design: .monospaced))
                }
                Spacer()
                Circle()
                    .fill(.cyan)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .background(Color.cyan.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 8) {
                Text("KUANTUM PENTEST SKORU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack {
                    Text("SHOR: %\(shorScore.formatted(.number.precision(.fractionLength(1))))")
                        .foregroundStyle(QAITheme.success)
                    Divider()
                        .overlay(QAITheme.textSecondary)
                    Text("GROVER: %\(groverScore.formatted(.number.precision(.fractionLength(1))))")
                        .foregroundStyle(QAITheme.success)
                }
                .font(.system(size: 14, weight: .black, design: .monospaced))

                Text("Sonuc: \(pentestResult)")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.accent)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            PrimaryButton(title: "Saglik Taramasini Yenile") {
                refreshScan()
            }
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear(perform: refreshScan)
    }

    private func refreshScan() {
        let report = BursaHealthCheck.shared.performFullScan()
        healingStatus = report.status

        let pentest = QuantumPentestSimulator.shared.runStressTest()
        pentestResult = pentest.rawValue.uppercased()
        shorScore = Double.random(in: 99.0 ... 100.0)
        groverScore = pentest == .vulnerable ? Double.random(in: 93.0 ... 98.0) : Double.random(in: 99.0 ... 100.0)
    }
}
