import SwiftUI

public struct IgnitionStatusView: View {
    @State private var isLive = false
    private let crown = NeuralCrownEntegrator.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 25) {
            VStack {
                Text("GLOBAL ATESLEME PROTOKOLU")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                    .bold()
                Button {
                    isLive.toggle()
                    GlobalSinirSistemi.paylasilan.veriPompala(
                        kategori: .sistem,
                        mesaj: isLive ? "Ignition dry-run aktif" : "Ignition dry-run kapatildi",
                        veri: ["live": isLive]
                    )
                } label: {
                    ZStack {
                        Circle()
                            .fill(isLive ? QAITheme.error : Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                        Image(systemName: "power")
                            .foregroundStyle(.white)
                            .font(.title)
                    }
                }

                Text(isLive ? "SISTEM HAZIR (DRY RUN)" : "SISTEM CEVRIMDISI")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isLive ? QAITheme.error : QAITheme.textSecondary)
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                Image(systemName: "applewatch")
                    .foregroundStyle(crown.isLinkAvailable ? QAITheme.success : QAITheme.error)
                VStack(alignment: .leading) {
                    Text("NEURAL CROWN LINK")
                        .font(.caption)
                        .bold()
                    Text(crown.isLinkAvailable ? "SENKRONIZE" : "BAGLANTI YOK")
                        .font(.system(size: 9))
                }
                Spacer()
                Button("Emergency Seal") {
                    crown.activateEmergencySeal()
                }
                .font(.caption2)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .background(QAITheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
