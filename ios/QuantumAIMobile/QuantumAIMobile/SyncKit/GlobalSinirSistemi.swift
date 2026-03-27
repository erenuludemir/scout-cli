import Foundation
import SwiftUI
import OSLog

public final class GlobalSinirSistemi: ObservableObject {
    public static let paylasilan = GlobalSinirSistemi()
    private let logger = Logger(subsystem: "com.quantumai.mobile", category: "sync")
    private let verboseSyncEnabled = ProcessInfo.processInfo.environment["QAI_VERBOSE_SYNC"] == "1"
    private let maxTelemetryEntries = 24
    private let bufferQueue = DispatchQueue(label: "com.quantumai.mobile.sync-buffer")
    private let flushDelay: TimeInterval = 0.02
    private var flushScheduled = false
    private var pendingBlockedIPCount = 0
    private var pendingSyncDate: Date?
    private var pendingEntries: [String] = []
    
    @Published public var hqBaglantiDurumu: Bool = true
    @Published public var blockedIPCount: Int = 0
    @Published public var sonSenkronizasyon: Date?
    @Published public private(set) var telemetryLog: [String] = []
    
    public init() {}

    public func veriPompala(kategori: OlayKategorisi, mesaj: String, veri: [String: Any]) {
        let entry = "[\(Date().formatted(.dateTime.hour().minute().second()))] [\(kategori.rawValue)] \(mesaj)"
        if verboseSyncEnabled {
            logger.debug("[\(kategori.rawValue.uppercased(), privacy: .public)] \(mesaj, privacy: .public)")
        }
        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.pendingSyncDate = .now
            self.pendingEntries.append(entry)
            self.scheduleFlushIfNeeded()
        }
    }

    public func registerBlockedIP(reason: String) {
        let entry = "[\(Date().formatted(.dateTime.hour().minute().second()))] [SECURITY] \(reason)"
        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.pendingBlockedIPCount += 1
            self.pendingSyncDate = .now
            self.pendingEntries.append(entry)
            self.scheduleFlushIfNeeded()
        }
    }

    private func scheduleFlushIfNeeded() {
        guard !flushScheduled else { return }
        flushScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + flushDelay) { [weak self] in
            self?.flushPendingUpdates()
        }
    }

    private func flushPendingUpdates() {
        let payload = bufferQueue.sync { () -> (Int, Date?, [String]) in
            let payload = (pendingBlockedIPCount, pendingSyncDate, pendingEntries)
            pendingBlockedIPCount = 0
            pendingSyncDate = nil
            pendingEntries.removeAll(keepingCapacity: true)
            flushScheduled = false
            return payload
        }

        if payload.0 > 0 {
            blockedIPCount += payload.0
        }
        if let syncDate = payload.1 {
            sonSenkronizasyon = syncDate
        }
        for entry in payload.2 {
            appendLog(entry)
        }
    }

    private func appendLog(_ entry: String) {
        telemetryLog.insert(entry, at: 0)
        if telemetryLog.count > maxTelemetryEntries {
            telemetryLog.removeLast(telemetryLog.count - maxTelemetryEntries)
        }
    }
}

public enum OlayKategorisi: String {
    case kar = "PROFIT"
    case alarm = "ALARM"
    case pazarlama = "MARKETING"
    case sistem = "SYSTEM_RECOVERY"
    case emir = "ORDER_EXEC"
}
