import SwiftUI

public struct BursaOpsPanelView: View {
    @EnvironmentObject private var env: AppEnvironment
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Operasyonel Metrikler
                    HStack(spacing: 15) {
                        MetricBox(title: "AKTİF BOTLAR", value: "12", color: QAITheme.accent)
                        MetricBox(title: "GÜNLÜK PNL", value: "+$1,240", color: QAITheme.success)
                    }
                    
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bursa Master Kontrol").font(.headline)
                            Divider().background(Color.gray)
                            
                            HStack {
                                Circle().fill(QAITheme.success).frame(width: 8, height: 8)
                                Text("Binance WebSocket: BAĞLI").font(.caption)
                            }
                            
                            HStack {
                                Circle().fill(QAITheme.success).frame(width: 8, height: 8)
                                Text("AI Sinyal Motoru: AKTİF").font(.caption)
                            }
                        }
                    }
                    
                    // Aktif Emirler Tablosu
                    VStack(alignment: .leading) {
                        Text("CANLI EMİRLER").font(.caption.bold()).foregroundColor(.gray).padding(.leading)
                        ForEach(0..<3) { _ in
                            HStack {
                                Text("BTC/USDT").bold()
                                Spacer()
                                Text("ALIM").foregroundColor(QAITheme.success)
                                Text("$68,450").monospaced()
                            }
                            .padding()
                            .background(QAITheme.cardBg)
                            .cornerRadius(4)
                        }
                    }
                }
                .padding()
            }
            .background(QAITheme.background)
            .navigationTitle("OPERASYON MERKEZİ")
        }
    }
}

struct MetricBox: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack {
            Text(title).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            Text(value).font(.title2.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(QAITheme.cardBg)
        .cornerRadius(8)
    }
}
