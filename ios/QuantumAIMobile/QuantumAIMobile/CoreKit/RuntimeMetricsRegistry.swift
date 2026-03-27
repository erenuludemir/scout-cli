import Foundation

@MainActor
public final class RuntimeMetricsRegistry: ObservableObject {
    @Published public private(set) var launches: Int = 0
    @Published public private(set) var liveTicks: Int = 0
    @Published public private(set) var simTicks: Int = 0
    @Published public private(set) var wsReconnects: Int = 0
    @Published public private(set) var restFallbacks: Int = 0

    public init() {}

    public func recordLaunch() {
        launches += 1
    }

    public func recordLiveTick() {
        liveTicks &+= 1
    }

    public func recordSimTick() {
        simTicks &+= 1
    }

    public func recordReconnect() {
        wsReconnects &+= 1
    }

    public func recordRestFallback() {
        restFallbacks &+= 1
    }
}
