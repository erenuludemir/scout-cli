#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

public final class NeuralCrownEntegrator: NSObject, WCSessionDelegate {
    public static let shared = NeuralCrownEntegrator()
    private let sinir = GlobalSinirSistemi.paylasilan

    public var isLinkAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.isPaired && session.isWatchAppInstalled
    }

    private override init() {
        super.init()
    }

    private func activateSessionIfPossible() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isPaired && session.isWatchAppInstalled else { return }
        session.delegate = self
        session.activate()
    }

    public func activateEmergencySeal() {
        activateSessionIfPossible()
        sinir.veriPompala(
            kategori: .alarm,
            mesaj: "WATCH EMERGENCY: Tum sistem muhurlendi.",
            veri: ["trigger": "AppleWatch_DigitalCrown", "status": "LOCKED_DOWN"]
        )
    }

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {}
}
#else
import Foundation

public final class NeuralCrownEntegrator {
    public static let shared = NeuralCrownEntegrator()

    public var isLinkAvailable: Bool { false }

    public init() {}

    public func activateEmergencySeal() {
        GlobalSinirSistemi.paylasilan.veriPompala(
            kategori: .alarm,
            mesaj: "WATCH EMERGENCY: Platform watch link desteklemiyor.",
            veri: [:]
        )
    }
}
#endif
