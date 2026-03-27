import SwiftUI

public struct PropertyIgnitionView: View {
    @ObservedObject private var mapEngine = Bursa3DMapEngine.shared
    @State private var isIgnited = false
    @State private var pulseOpacity = 0.5

    public init() {}

    public var body: some View {
        VStack(spacing: 25) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(QAITheme.panelBlue.opacity(0.1))
                    .frame(height: 180)

                VStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.largeTitle)
                        .foregroundStyle(QAITheme.panelBlue)
                    Text("OSMANGAZI / BURSA 3D VAULT")
                        .font(.caption)
                        .bold()
                    Text("Aktif Muhurlu tapu: \(mapEngine.highlightedProperties.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(QAITheme.textSecondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(QAITheme.panelBlue.opacity(0.3), lineWidth: 1)
            )

            HStack {
                VStack(alignment: .leading) {
                    Text("MULK PASIF AKISI")
                        .font(.caption2)
                        .foregroundStyle(QAITheme.textSecondary)
                    Text("+$\(String(format: "%.2f", mapEngine.activeRentFlow))")
                        .foregroundStyle(QAITheme.success)
                        .bold()
                }
                Spacer()
                Button("SYNC") {
                    mapEngine.triggerPassiveIncomeSync()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                isIgnited.toggle()
                GlobalSinirSistemi.paylasilan.veriPompala(
                    kategori: .sistem,
                    mesaj: "PROPERTY IGNITION: dry-run atesleme durumu degisti.",
                    veri: ["ignited": isIgnited]
                )
            } label: {
                ZStack {
                    Circle()
                        .fill(isIgnited ? QAITheme.accent : QAITheme.error)
                        .frame(width: 90, height: 90)
                        .opacity(pulseOpacity)
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(Color.white)
                        .font(.title)
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseOpacity = 1.0
                }
            }

            Text(isIgnited ? "OPERASYON CANLI (DRY RUN)" : "ATESLEME ICIN DOKUN")
                .font(.caption)
                .bold()
                .foregroundStyle(isIgnited ? QAITheme.accent : QAITheme.error)
        }
        .padding()
        .navigationTitle("Property & Ignition")
    }
}
