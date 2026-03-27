import Foundation
import SwiftUI

@MainActor
public final class EternalLoopEngine: ObservableObject {
    public static let shared = EternalLoopEngine()

    @Published public private(set) var isRunning = false
    @Published public private(set) var uptimeSeconds = 0
    @Published public private(set) var lastHeartbeat: Date?

    private var timer: Timer?

    private init() {}

    public func initiateEternalLoop() {
        guard !isRunning else { return }
        isRunning = true
        lastHeartbeat = .now

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.uptimeSeconds += 1
                self.lastHeartbeat = .now
                if self.uptimeSeconds.isMultiple(of: 10) {
                    GlobalSinirSistemi.paylasilan.veriPompala(
                        kategori: .sistem,
                        mesaj: "ETERNAL LOOP: heartbeat",
                        veri: ["uptime": self.uptimeSeconds]
                    )
                }
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    deinit {
        timer?.invalidate()
    }
}
