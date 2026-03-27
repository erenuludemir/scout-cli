import Foundation

public final class MainnetFirewall {
    public static let shared = MainnetFirewall()

    private init() {}

    public func authorizeMainnetRelease(order: Order) -> Bool {
        if order.amount >= 1_000_000 {
            GlobalSinirSistemi.paylasilan.veriPompala(
                kategori: .alarm,
                mesaj: "FIREWALL: 1M$ senaryosu amiral onayi bekliyor.",
                veri: ["order_id": order.id, "amount": order.amount]
            )
            return false
        }

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "FIREWALL: emir dry-run gecis onayi aldi.",
            veri: ["order_id": order.id]
        )
        return true
    }
}
