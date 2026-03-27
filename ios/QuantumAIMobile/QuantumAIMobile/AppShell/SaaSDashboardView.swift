import SwiftUI

public struct SaaSDashboardView: View {
    @ObservedObject private var tokenFactory = TokenFactory.shared
    @ObservedObject private var branding = PartnerBrandingEngine.shared

    @State private var activePartners = 4
    @State private var gatewayLoad = 0.28

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("SAAS API GATEWAY YUKU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: gatewayLoad)
                        .stroke(QAITheme.panelBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("%\(Int(gatewayLoad * 100))")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(width: 72, height: 72)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("URETILEN TOKENLAR")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("\(tokenFactory.deployedTokens.count)")
                        .font(.title2)
                        .bold()
                }
                Spacer()
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(QAITheme.warning)
                    .font(.title)
            }
            .padding()
            .background(QAITheme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("AKTIF KURUMSAL PARTNERLER")
                    .font(.caption)
                    .bold()
                partnerRow("Osmangazi_Bank_X")
                partnerRow("Bursa_Invest_Grp")
                partnerRow("Partner_\(activePartners)")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                Button("Tema: Bank") {
                    branding.applyPartnerTheme(partnerID: "OSMANGAZI_BANK_X")
                }
                .buttonStyle(.bordered)

                Button("Dry-Run Token") {
                    tokenFactory.deployToken(name: "Bursa Utility", symbol: "BURSA", supply: 1_000_000, network: .erc20)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("SaaS & Token")
    }

    private func partnerRow(_ name: String) -> some View {
        HStack {
            Label(name, systemImage: "building.columns.fill")
            Spacer()
            Text("ONLINE")
                .foregroundStyle(QAITheme.success)
                .font(.system(size: 8))
        }
    }
}
