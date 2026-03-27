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
                            ForEach(Array(env.watchlist.prices.values)) { item in
                                MarketRow(symbol: item.id, price: item.price, change: "+2.4%")
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
