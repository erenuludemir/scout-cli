import SwiftUI

public struct HedgeFundDashboardView: View {
    @EnvironmentObject private var env: AppEnvironment
    
    var totalEquity: Double {
        // Cüzdan bakiyelerinin toplamı (Örn: 125,450.00 USD)
        return 125450.00 
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Toplam Varlık") {
                    Text(String(format: "$%.2f", totalEquity))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundColor(QAITheme.success)
                }
                
                Section("Cüzdanlar (Multi-Chain)") {
                    WalletRow(name: "EVM (BSC/ETH)", addr: "0x71C...4f2", balance: "$45,200")
                    WalletRow(name: "TRON", addr: "TY9...qWp", balance: "$12,850")
                    WalletRow(name: "SOLANA", addr: "6kP...zR8", balance: "$67,400")
                }
                
                Section("AI Karar Sinyali") {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Sinyal: ").bold()
                        Text("BEKLE (Nötr)").foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Hedge Fonu Paneli")
            .scrollContentBackground(.hidden)
            .background(AppBackground())
        }
    }
}

struct WalletRow: View {
    let name: String; let addr: String; let balance: String
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(addr).font(.caption).monospaced().foregroundColor(.gray)
            }
            Spacer()
            Text(balance).bold()
        }
    }
}
