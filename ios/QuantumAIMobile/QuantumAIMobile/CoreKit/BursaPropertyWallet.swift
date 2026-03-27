import Foundation

@MainActor
public final class BursaPropertyWallet: ObservableObject {
    public static let shared = BursaPropertyWallet()

    @Published public private(set) var propertyTitles: [String] = [
        "Osmangazi Arsa-01",
        "Nilufer Office-04"
    ]

    private init() {}

    public func sealNewProperty(id: String, location: String) -> String {
        let signature = "LAT-\(UUID().uuidString.prefix(16))"
        _ = QuantumLedger.shared.sealTransaction(orderId: id, data: "DEED_SEALED_\(location)")

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "MULK MUHURLENDI: \(location)",
            veri: ["signature": signature]
        )

        if !propertyTitles.contains(location) {
            propertyTitles.append(location)
        }

        return signature
    }
}
