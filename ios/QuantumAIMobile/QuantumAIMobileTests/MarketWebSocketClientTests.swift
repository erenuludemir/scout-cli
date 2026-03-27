import XCTest
@testable import QuantumAIMobile

final class MarketWebSocketClientTests: XCTestCase {
    func testOneShotThrowingContinuationIgnoresDuplicateResume() async throws {
        let continuation = OneShotThrowingContinuation<Void>()

        try await withCheckedThrowingContinuation { checkedContinuation in
            continuation.install(checkedContinuation)
            continuation.resume()
            continuation.resume(with: .failure(URLError(.cancelled)))
        }
    }

    func testOneShotThrowingContinuationStoresPendingFailureUntilInstalled() async {
        let continuation = OneShotThrowingContinuation<Void>()
        continuation.resume(with: .failure(CancellationError()))

        do {
            try await withCheckedThrowingContinuation { checkedContinuation in
                continuation.install(checkedContinuation)
            }
            XCTFail("Bekleyen hata install sonrasında iletilmeliydi.")
        } catch is CancellationError {
        } catch {
            XCTFail("Beklenmeyen hata: \(error)")
        }
    }
}
