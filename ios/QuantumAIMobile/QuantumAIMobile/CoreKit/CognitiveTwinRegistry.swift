import Foundation

@MainActor
public final class CognitiveTwinRegistry: ObservableObject {
    public static let shared = CognitiveTwinRegistry()

    @Published public private(set) var heirName = "Guney Uras"
    @Published public private(set) var syncProgress: Double = 0.61
    @Published public private(set) var maturityLevel: Double = 0.54
    @Published public private(set) var mentorMode = "FOUNDATION"
    @Published public private(set) var statusText = "Bilisel aktarim hazir"
    @Published public private(set) var knowledgeBase = "AMIRAL_HFT_QKD_SOURCE_CODE"

    private let sinir = GlobalSinirSistemi.paylasilan

    public init() {}

    public func mentorHeir(currentHeirAgeMonths: Int) {
        if currentHeirAgeMonths >= 54 {
            mentorMode = "FOUNDATION"
            syncProgress = min(0.999, syncProgress + 0.12)
            maturityLevel = min(1.0, maturityLevel + 0.08)
            statusText = "Usta protokolu egitimde"
        } else {
            mentorMode = "SEED"
            syncProgress = min(0.999, syncProgress + 0.04)
            maturityLevel = min(1.0, maturityLevel + 0.02)
            statusText = "Temel senkronizasyon calisiyor"
        }

        sinir.veriPompala(
            kategori: .sistem,
            mesaj: "BILISEL IKIZ SENKRONIZASYONU GUNCELLENDI",
            veri: [
                "heir": heirName,
                "mode": mentorMode,
                "sync": syncProgress,
                "maturity": maturityLevel
            ]
        )
    }
}
