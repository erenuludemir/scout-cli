import Foundation
import Combine

@MainActor
public final class AlertService: ObservableObject {
    private let market: MarketDataService
    private let metrics: MetricsCenter
    
    // Görüntüdeki AnyCancellable sızıntısını önlemek için Task yapısına geçiyoruz
    private var alertTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(market: MarketDataService, metrics: MetricsCenter) {
        self.market = market
        self.metrics = metrics
        setupAlertListener()
    }

    private func setupAlertListener() {
        // Eski abonelikleri temizle
        alertTask?.cancel()
        
        // Market verilerini sızıntı yapmadan dinle
        market.$last
            .compactMap { $0 }
            .sink { [weak self] tick in
                guard let self = self else { return }
                self.checkPriceAlerts(price: tick.price)
            }
            .store(in: &cancellables)
    }

    private func checkPriceAlerts(price: Double) {
        // Burada alarm mantığı çalışacak
        // Örn: Eğer fiyat > eşik değerse log at veya bildirim gönder
    }
    
    public func stop() {
        alertTask?.cancel()
        alertTask = nil
        cancellables.removeAll()
    }

    deinit {
        // AlertService bellekten atılırken her şeyi serbest bırak
        cancellables.removeAll()
        alertTask?.cancel()
    }
}
