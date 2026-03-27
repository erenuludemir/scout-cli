import SwiftUI

public struct SecurityMonitorView: View {
    @ObservedObject private var sinir = GlobalSinirSistemi.paylasilan
    @State private var sentinelActive = true

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("BURSA SENTINEL")
                        .font(.caption)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text(sentinelActive ? "KALKAN: AKTIF" : "KALKAN: DEVRE DISI")
                        .font(.headline)
                        .foregroundStyle(sentinelActive ? QAITheme.success : QAITheme.error)
                }
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(QAITheme.success)
                    .font(.title)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("SON YASAL MUHURLER")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)

                if sinir.telemetryLog.isEmpty {
                    Text("Kayit bekleniyor")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(QAITheme.textSecondary)
                } else {
                    ForEach(Array(sinir.telemetryLog.prefix(2).enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(QAITheme.panelBlue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
