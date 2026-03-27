import SwiftUI

public struct PartnerCommandView: View {
    @ObservedObject private var branding = PartnerBrandingEngine.shared
    @State private var hqTotalValue: Double = 52_400_150.0

    public init() {}

    public var body: some View {
        VStack(spacing: 25) {
            VStack {
                Text("BURSA HQ TOTAL EQUITY")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                    .bold()
                Text("$\(String(format: "%.2f", hqTotalValue))")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(branding.primaryThemeColor)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(branding.primaryThemeColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading) {
                Text("AKTIF WHITE-LABEL KANALLARI")
                    .font(.caption)
                    .bold()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        PartnerCommandCard(name: "Bursa HQ", color: QAITheme.accent, active: branding.currentPartnerName.contains("BURSA"))
                            .onTapGesture { branding.applyPartnerTheme(partnerID: "BURSA_HQ") }
                        PartnerCommandCard(name: "Bank-X", color: QAITheme.panelBlue, active: branding.currentPartnerName.contains("BANK"))
                            .onTapGesture { branding.applyPartnerTheme(partnerID: "OSMANGAZI_BANK_X") }
                        PartnerCommandCard(name: "Invest-Grp", color: QAITheme.warning, active: branding.currentPartnerName.contains("INVEST"))
                            .onTapGesture { branding.applyPartnerTheme(partnerID: "BURSA_INVEST_01") }
                    }
                }
            }

            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(QAITheme.accent)
                Text("AI onerisi: gayrimenkul / nakit orani dengeli.")
                    .font(.caption)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .navigationTitle(branding.currentPartnerName)
    }
}

private struct PartnerCommandCard: View {
    let name: String
    let color: Color
    let active: Bool

    var body: some View {
        VStack {
            Image(systemName: "building.2.fill")
                .font(.title2)
            Text(name)
                .font(.system(size: 10, weight: .bold))
        }
        .frame(width: 80, height: 80)
        .background(color.opacity(active ? 0.3 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(color.opacity(active ? 1.0 : 0.3), lineWidth: 1)
        )
    }
}
