import Foundation

@MainActor
public final class TelepathyGateway: ObservableObject {
    public static let shared = TelepathyGateway()

    @Published public private(set) var neuralSyncPhase: Double = 0.87
    @Published public private(set) var lastIntentCode = "INTENT_MONITOR"
    @Published public private(set) var lastLatencyMs: Double = 0.012
    @Published public private(set) var activeThoughts: [String] = [
        "PIYASAYI TARA",
        "RISKI MINIMIZE ET",
        "BEKLEMEDE KAL"
    ]

    public init() {}

    public func processBrainwaveCommand(intentCode: String) {
        let started = DispatchTime.now().uptimeNanoseconds
        lastIntentCode = intentCode
        neuralSyncPhase = min(1.0, neuralSyncPhase + 0.02)

        let renderedIntent = switch intentCode {
        case "INTENT_AGGRESSIVE_BUY": "AGRESIF ALIM"
        case "INTENT_ABSOLUTE_ZERO": "SISTEMI KILITLE"
        case "INTENT_QKD_MONITOR": "QKD IZLEME"
        default: "STRATEJIK IZLEME"
        }

        activeThoughts.insert(renderedIntent, at: 0)
        if activeThoughts.count > 8 {
            activeThoughts.removeLast(activeThoughts.count - 8)
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        lastLatencyMs = max(0.012, elapsed)

        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .sistem,
            mesaj: "NORAL KOMUT ISLENDI: \(intentCode)",
            veri: [
                "latency_ms": lastLatencyMs,
                "intent": intentCode,
                "sync": neuralSyncPhase
            ]
        )
    }
}
