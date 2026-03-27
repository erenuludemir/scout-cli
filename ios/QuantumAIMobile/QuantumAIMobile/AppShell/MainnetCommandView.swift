import SwiftUI

public struct MainnetCommandView: View {
    @State private var liveMode = false
    @ObservedObject private var propertyWallet = BursaPropertyWallet.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $liveMode) {
                    VStack(alignment: .leading) {
                        Text("LIVE MAINNET MODE")
                            .bold()
                            .foregroundStyle(QAITheme.error)
                        Text("Kuantum emirleri burada sadece dry-run calisir")
                            .font(.caption2)
                            .foregroundStyle(QAITheme.textSecondary)
                    }
                }
                .padding()
                .background(liveMode ? QAITheme.error.opacity(0.1) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            VStack(alignment: .leading) {
                Text("PROPERTY WALLET (NFT-TAPU)")
                    .font(.caption)
                    .foregroundStyle(QAITheme.textSecondary)
                    .bold()
                ForEach(propertyWallet.propertyTitles, id: \.self) { property in
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundStyle(QAITheme.panelBlue)
                        Text(property)
                            .font(.system(size: 14, design: .monospaced))
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(QAITheme.success)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            PrimaryButton(title: "First Quantum Order Fire (Dry Run)") {
                guard liveMode else { return }
                GlobalSinirSistemi.paylasilan.veriPompala(
                    kategori: .emir,
                    mesaj: "MAINNET DRY RUN: Manuel quantum emir simule edildi.",
                    veri: ["mode": "dry_run"]
                )
            }
        }
        .padding()
        .navigationTitle("Mainnet HQ")
    }
}
