import Foundation
import SwiftUI
import SceneKit

@MainActor
public final class Bursa3DMapEngine: ObservableObject {
    public static let shared = Bursa3DMapEngine()

    @Published public var activeRentFlow: Double = 1240.50
    @Published public private(set) var highlightedProperties: [String] = [
        "Osmangazi Arsa-01",
        "Nilufer Office-04",
        "Mudanya Villa-02",
        "Gursu Depot-01"
    ]

    private init() {}

    public func getPropertyCoordinate(id: String) -> SCNVector3 {
        switch id {
        case "Osmangazi Arsa-01":
            return SCNVector3(x: 40.183, y: 29.061, z: 0)
        case "Nilufer Office-04":
            return SCNVector3(x: 40.220, y: 28.962, z: 0)
        case "Mudanya Villa-02":
            return SCNVector3(x: 40.376, y: 28.882, z: 0)
        default:
            return SCNVector3(x: 40.200, y: 29.030, z: 0)
        }
    }

    public func triggerPassiveIncomeSync() {
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .kar,
            mesaj: "PASIF GELIR: mulk muhurlulerinden gelen akis onaylandi.",
            veri: ["amount": activeRentFlow]
        )
    }
}
