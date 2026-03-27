import Foundation
import Combine

public final class WatchlistService: ObservableObject {
    @Published public var items: [String] = ["BTCUSDT", "ETHUSDT", "BNBUSDT"]
    
    public init() {}
    
    public func add(_ symbol: String) {
        if !items.contains(symbol) {
            items.append(symbol)
        }
    }
}
