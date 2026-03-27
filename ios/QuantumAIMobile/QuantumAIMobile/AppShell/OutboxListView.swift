import SwiftUI

public struct OutboxListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(env.storage.outbox) { order in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(order.desc).font(.headline)
                        Text("Tutar: \(String(format: "$%.2f", order.usd))")
                            .font(.subheadline)
                        Text("ID: \(order.idempotencyKey.prefix(12))...")
                            .font(.caption)
                            .monospaced()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let order = env.storage.outbox[index]
                        env.storage.removeFromOutbox(order.id)
                    }
                }
            }
            .navigationTitle("Bekleyen İşlemler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hepsini Gönder") {
                        Task {
                            await env.sync.flushOutbox()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
