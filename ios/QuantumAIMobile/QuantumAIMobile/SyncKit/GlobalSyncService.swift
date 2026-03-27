import Foundation

/// BURSA HQ - Klasik Senkronizasyon Arayüzü (Legacy Wrapper)
/// Bu servis, eski çağrıları yeni nesil 'GlobalSinirSistemi'ne yönlendirir.
public final class GlobalSyncService {
    public static let shared = GlobalSyncService()
    private let sinir = GlobalSinirSistemi.paylasilan
    
    private init() {}

    /// Eski tip sync çağrılarını Sinir Sistemi kategorilerine haritalar
    public func syncToHQ(type: String, data: [String: Any]) {
        let kategori: OlayKategorisi
        
        switch type {
        case "ORDER": kategori = .emir
        case "ALERT": kategori = .alarm
        case "MARKETING": kategori = .pazarlama
        default: kategori = .sistem
        }
        
        // Yeni nesil sinir sistemine veri pompala
        sinir.veriPompala(
            kategori: kategori,
            mesaj: "Legacy Sync: [\(type)] iletildi",
            veri: data
        )

        print("[LEGACY-SYNC] [\(type)] verisi sinir sistemine aktarildi.")
    }
}
