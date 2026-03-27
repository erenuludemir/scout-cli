import XCTest
import Combine
@testable import QuantumAIMobile

@MainActor
final class MarketDataTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    func testBinanceAdapterParsesAggTradePayload() {
        let json = """
        {"e":"aggTrade","E":1711363200123,"s":"BTCUSDT","p":"67234.15000000","q":"0.04200000","T":1711363200000}
        """

        guard let tick = BinanceAdapter.parseTick(from: json) else {
            return XCTFail("AggTrade payload ayrıştırılamadı")
        }

        XCTAssertEqual(tick.price, 67_234.15, accuracy: 0.0001)
        XCTAssertEqual(tick.vol, 0.042, accuracy: 0.000001)
        XCTAssertEqual(tick.ts.timeIntervalSince1970, 1_711_363_200, accuracy: 0.001)
    }

    func testMarketSimProducesTicks() {
        let metrics = MetricsCenter()
        let sut = MarketDataService(metrics: metrics)
        let exp = expectation(description: "tick")

        sut.$last
            .compactMap { $0 }
            .prefix(1)
            .sink { tick in
                XCTAssertNotNil(tick)
                exp.fulfill()
            }
            .store(in: &cancellables)

        sut.startIfNeeded(simMode: true)
        wait(for: [exp], timeout: 2.5)
        XCTAssertEqual(sut.sourceText, "Simülasyon")
        XCTAssertEqual(sut.statusText, "Otomatik")
        sut.stopAll()
    }

    func testMarketReconfigureStartsServiceWhenCalledCold() {
        let metrics = MetricsCenter()
        let sut = MarketDataService(metrics: metrics)
        let exp = expectation(description: "tick after reconfigure")

        sut.$last
            .compactMap { $0 }
            .prefix(1)
            .sink { _ in
                exp.fulfill()
            }
            .store(in: &cancellables)

        sut.reconfigure(simMode: true, symbol: " btc/usdt ")

        wait(for: [exp], timeout: 2.5)
        XCTAssertEqual(sut.sourceText, "Simülasyon")
        XCTAssertEqual(sut.statusText, "Otomatik")
        sut.stopAll()
    }

    func testNormalizedSymbolTrimsUppercasesAndFallsBack() {
        XCTAssertEqual(MarketDataService.normalizedSymbol(" btc/usdt "), "BTCUSDT")
        XCTAssertEqual(MarketDataService.normalizedSymbol("  "), "BTCUSDT")
        XCTAssertEqual(MarketDataService.normalizedSymbol("eth-usdt"), "ETHUSDT")
    }

    @MainActor
    func testCoinMarketCapBridgeMapsKnownSymbolsToStableURLs() {
        let sut = CoinMarketCapBridgeService()
        XCTAssertEqual(sut.bridgeURL(for: "BTCUSDT").absoluteString, "https://coinmarketcap.com/currencies/bitcoin/")
        XCTAssertEqual(sut.bridgeURL(for: "ETHUSDT").absoluteString, "https://coinmarketcap.com/currencies/ethereum/")
        XCTAssertEqual(sut.bridgeURL(for: "SOLUSDT").absoluteString, "https://coinmarketcap.com/currencies/solana/")
    }

    func testTrainingGuideLoadsBundledSectionsAndPresets() {
        let sut = TrainingGuideStore()
        sut.loadIfNeeded(synchronously: true)

        XCTAssertFalse(sut.guide.sections.isEmpty)
        XCTAssertFalse(sut.guide.presets.isEmpty)
        XCTAssertNotEqual(sut.guide.summary, "Kaynak bekleniyor")
        XCTAssertTrue(sut.guide.presets.allSatisfy { preset in
            sut.section(withID: preset.sourceSectionID) != nil
        })
    }

    func testTrainingResourcesResolveFromBundle() {
        XCTAssertNotNil(ResourceBundle.url(forResource: "TrainingV140721", withExtension: "html", subdirectory: "Training"))
        XCTAssertNotNil(ResourceBundle.url(forResource: "Training_v2", withExtension: "pdf", subdirectory: "Training"))
    }
}
