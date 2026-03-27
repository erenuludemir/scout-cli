import SwiftUI

public struct NetworkMonitorView: View {
    @ObservedObject private var hq = GlobalSinirSistemi.paylasilan
    @State private var ping: Int = 12
    @State private var linkStatus: String = "FIBER"
    @State private var activeVaults: Int = 8

    public init() {}

    public var body: some View {
        VStack(spacing: 15) {
            HStack {
                Circle()
                    .fill(linkStatus == "FIBER" ? QAITheme.success : QAITheme.accent)
                    .frame(width: 10, height: 10)
                Text("BAGLANTI: \(linkStatus)")
                    .font(.system(size: 10, design: .monospaced))
                Spacer()
                Text("\(ping)ms")
                    .foregroundStyle(QAITheme.success)
                    .font(.caption2)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))

            HStack {
                VStack(alignment: .leading) {
                    Text("AKTIF VAULTS")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("\(activeVaults) Partner Hucresi")
                        .font(.headline)
                        .foregroundStyle(QAITheme.textPrimary)
                }
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(QAITheme.panelBlue)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [QAITheme.panelBlue.opacity(0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let lastSync = hq.sonSenkronizasyon {
                HStack {
                    Text("SON HQ PING")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Spacer()
                    Text(lastSync.formatted(.dateTime.hour().minute().second()))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(QAITheme.textPrimary)
                }
            }
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
