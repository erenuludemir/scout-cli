import SwiftUI

public struct BinanceMasterPanel: View {
    @EnvironmentObject private var env: AppEnvironment
    
    public var body: some View {
        NavigationStack {
            ZStack {
                QAITheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Üst Özet Kartları
                        HStack(spacing: 12) {
                            SummaryStatCard(title: "TOPLAM HACİM", value: "$2.4M", icon: "chart.bar.fill")
                            SummaryStatCard(title: "AKTİF EMİRLER", value: "42", icon: "list.bullet.rectangle")
                        }
                        
                        // 2. Canlı İzleme Listesi (Watchlist)
                        VStack(alignment: .leading) {
                            Text("PİYASA TAKİBİ").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
                            ForEach(env.watchlist.items, id: \.self) { symbol in
                                MarketRow(symbol: symbol, price: previewPrice(for: symbol), change: "+2.4%")
                            }
                        }
                        .padding()
                        .background(QAITheme.cardBg)
                        .cornerRadius(8)
                        
                        // 3. AI Karar Destek Göstergesi
                        HStack {
                            VStack(alignment: .leading) {
                                Text("AI STRATEJİ MOTORU").font(.caption).foregroundColor(.gray)
                                Text("ALIMLARI DURDUR: RİSK YÜKSEK").font(.headline).foregroundColor(QAITheme.warning)
                            }
                            Spacer()
                            Image(systemName: "brain.head.profile").font(.title).foregroundColor(QAITheme.accent)
                        }
                        .padding()
                        .background(QAITheme.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(QAITheme.warning.opacity(0.3), lineWidth: 1))
                    }
                    .padding()
                }
            }
            .navigationTitle("BINANCE KONTROL")
        }
    }
}

private func previewPrice(for symbol: String) -> Double {
    switch symbol {
    case "ETHUSDT":
        return 3_200
    case "BNBUSDT":
        return 620
    default:
        return 68_450
    }
}

private struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(QAITheme.accent)
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(QAITheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(QAITheme.cardBg)
        .cornerRadius(8)
    }
}

struct MarketRow: View {
    let symbol: String; let price: Double; let change: String
    var body: some View {
        HStack {
            Text(symbol).bold()
            Spacer()
            Text(String(format: "$%.2f", price)).monospaced()
            Text(change).foregroundColor(QAITheme.success).font(.caption)
        }
        .padding(.vertical, 8)
    }
}
