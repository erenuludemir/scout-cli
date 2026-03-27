import SwiftUI

public struct ComplianceMonitorView: View {
    @State private var pciStatus = "Uyumlu (v4.0.1)"
    @State private var throughput = 1250
    @State private var vaultsActive = 12

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(QAITheme.success)
                VStack(alignment: .leading) {
                    Text("PCI DSS GUVENLIK STANDARDI")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text(pciStatus)
                        .font(.headline)
                        .bold()
                }
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack {
                Text("PIPELINE THROUGHPUT")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<10, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(QAITheme.success)
                            .frame(width: 10, height: CGFloat.random(in: 20...60))
                    }
                }
                Text("\(throughput) TX / SEC")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Label("\(vaultsActive) Aktif Partner Kasasi", systemImage: "lock.shield")
                Spacer()
                Circle()
                    .fill(QAITheme.success)
                    .frame(width: 8, height: 8)
            }
            .padding()
            .font(.caption)
            .background(QAITheme.panelBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding()
    }
}
