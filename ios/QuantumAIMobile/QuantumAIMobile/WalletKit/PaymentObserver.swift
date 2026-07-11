import Foundation

public final class PaymentObserver: ObservableObject {
    @Published public var isVerifying = false
    
    public init() {}

    public func activateFreeAccess() async -> Bool {
        await MainActor.run { isVerifying = true }
        try? await Task.sleep(nanoseconds: 700_000_000)
        await MainActor.run { isVerifying = false }
        return true
    }
}
