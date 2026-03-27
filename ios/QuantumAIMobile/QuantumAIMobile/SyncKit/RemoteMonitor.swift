import Foundation
import Combine

@MainActor public final class RemoteMonitor: ObservableObject {
    private let env: AppEnvironment
    private var cancellables = Set<AnyCancellable>()
    private let sinir = GlobalSinirSistemi.paylasilan
    
    public init(env: AppEnvironment) {
        self.env = env
        setupSubscribers()
    }
    
    private func setupSubscribers() {
        env.market.$last
            .compactMap { $0 }
            .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] tick in
                self?.sinir.veriPompala(
                    kategori: .emir,
                    mesaj: "Canlı Fiyat Güncellemesi: \(String(format: "%.2f", tick.price))",
                    veri: ["symbol": "BTCUSDT", "price": tick.price]
                )
            }
            .store(in: &cancellables)
            
        env.watchlist.$items
            .sink { [weak self] items in
                self?.sinir.veriPompala(
                    kategori: .sistem,
                    mesaj: "İzleme Listesi Senkronize: \(items.count) sembol",
                    veri: ["count": items.count]
                )
            }
            .store(in: &cancellables)
            
        env.bot.$activeOrders
            .sink { [weak self] orders in
                if let lastOrder = orders.first {
                    self?.sinir.veriPompala(
                        kategori: .emir,
                        mesaj: "Yeni Bot Emri İletildi: \(lastOrder.side)",
                        veri: ["id": lastOrder.id, "side": lastOrder.side, "price": lastOrder.price]
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    public func forceSync() {
        sinir.veriPompala(kategori: .sistem, mesaj: "MANUEL SENKRONİZASYON BAŞLATILDI", veri: [:])
    }
    
    deinit {
        cancellables.removeAll()
    }
}

