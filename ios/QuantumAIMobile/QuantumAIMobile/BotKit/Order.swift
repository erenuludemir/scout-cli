import Foundation

public struct Order: Identifiable, Codable {
    public let id: String
    public let symbol: String
    public let side: String
    public let price: Double
    public let amount: Double
    public let timestamp: Date
    
    public init(id: String, symbol: String, side: String, price: Double, amount: Double, timestamp: Date) {
        self.id = id
        self.symbol = symbol
        self.side = side
        self.price = price
        self.amount = amount
        self.timestamp = timestamp
    }

    /// WalletView ve CopyTradeService için gerekli kopyalama metodu
    public static func marketCopy(_ original: Order, at newPrice: Double) -> Order {
        return Order(
            id: UUID().uuidString.prefix(8).lowercased(),
            symbol: original.symbol,
            side: original.side,
            price: newPrice,
            amount: original.amount,
            timestamp: .now
        )
    }
}
