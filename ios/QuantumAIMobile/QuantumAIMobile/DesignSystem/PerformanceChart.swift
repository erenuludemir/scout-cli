import SwiftUI

public struct PricePoint: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let price: Double

    public init(date: Date, price: Double) {
        self.date = date
        self.price = price
    }
}

public struct PerformanceChart: View {
    let data: [PricePoint]

    public init(data: [PricePoint]) {
        self.data = data
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(QAITheme.cardBg)
                if data.count >= 2 && proxy.size.width > 1 && proxy.size.height > 1 {
                    Path { path in
                        let minPrice = data.map(\.price).min() ?? 0
                        let maxPrice = data.map(\.price).max() ?? 1
                        let span = max(maxPrice - minPrice, 1)
                        for (index, point) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let yRatio = (point.price - minPrice) / span
                            let y = height - (height * CGFloat(yRatio))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(QAITheme.accent, lineWidth: 2)
                } else {
                    Text("Grafik verisi bekleniyor")
                        .foregroundStyle(QAITheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipped()
        }
        .frame(height: 220)
    }
}
