import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct OrdersView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        ZStack {
            AppBackground()

            if env.bot.activeOrders.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Henüz bir kayıt bulunamadı.")
                        .foregroundColor(.gray)
                }
            } else {
                List(env.bot.activeOrders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(order.symbol)
                                .font(.headline)
                            Spacer()
                            Text(order.side)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(order.side == "BUY" ? QAITheme.success.opacity(0.2) : QAITheme.warning.opacity(0.2))
                                .foregroundColor(order.side == "BUY" ? QAITheme.success : QAITheme.warning)
                                .cornerRadius(4)
                        }

                        HStack {
                            Label("$\(String(format: "%.2f", order.price))", systemImage: "tag")
                            Spacer()
                            Label("\(String(format: "%.4f", order.amount))", systemImage: "chart.bar.fill")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Text("ID: \(order.id)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .listRowBackground(Color.white.opacity(0.02))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Kayıtlar")
    }
}
