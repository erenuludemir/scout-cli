import Foundation

public struct Tick: Codable, Equatable {
    public let ts: Date
    public let price: Double
    public let vol: Double

    public init(ts: Date, price: Double, vol: Double) {
        self.ts = ts
        self.price = price
        self.vol = vol
    }
}
