import SwiftUI

public struct EnterpriseTelemetryCard: View {
    @ObservedObject private var hq: GlobalSinirSistemi
    @ObservedObject private var wealthBridge: WealthBridge

    public init(hq: GlobalSinirSistemi, wealthBridge: WealthBridge) {
        _hq = ObservedObject(wrappedValue: hq)
        _wealthBridge = ObservedObject(wrappedValue: wealthBridge)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BURSA HQ WORKSPACE")
                        .font(.system(size: 12, weight: .black))
                        .tracking(1.6)
                    Text("Neural, sync ve transfer telemetrisi")
                        .font(.caption)
                        .foregroundStyle(QAITheme.textSecondary)
                }
                Spacer()
                Text("\(hq.blockedIPCount) BLOKE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(QAITheme.error.opacity(0.16))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                metric(title: "WEALTH", value: wealthBridge.statusText)
                metric(title: "ESIK", value: "$\(Int(wealthBridge.profitThreshold))")
                metric(title: "SYNC", value: hq.hqBaglantiDurumu ? "ONLINE" : "OFFLINE")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SON TELEMETRI")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                if hq.telemetryLog.isEmpty {
                    Text("Kayit bekleniyor")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(QAITheme.textSecondary)
                } else {
                    ForEach(Array(hq.telemetryLog.prefix(3).enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(QAITheme.textPrimary)
                    }
                }
            }
        }
        .padding()
        .background(QAITheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(QAITheme.border, lineWidth: 1)
        )
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(QAITheme.textSecondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(QAITheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
