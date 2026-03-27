import SwiftUI

public struct WhaleRadarView: View {
    @State private var whaleLogs = [
        "[09:42] 500 BTC -> Binance (Alert)",
        "[09:45] Smart Money: ETH Pozisyon Arttirdi",
        "[09:50] Whale Accumulation: $ABC Token %2"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("BORSALARA TRANSFER ETKISI")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                HStack {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .foregroundStyle(QAITheme.error)
                    Text("SATIS BASKISI: %62")
                        .font(.headline)
                        .bold()
                }
            }
            .padding()
            .background(QAITheme.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading) {
                Text("AKILLI PARA AKISI")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(QAITheme.panelBlue)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(whaleLogs, id: \.self) { log in
                            HStack {
                                Circle()
                                    .fill(log.contains("Binance") ? QAITheme.error : QAITheme.success)
                                    .frame(width: 6, height: 6)
                                Text(log)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("AKTIVITEYI YENILE") {
                whaleLogs = OnChainRadar.shared.fetchWhaleActivity().map { "[LIVE] \($0)" }
            }
            .font(.caption2)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
