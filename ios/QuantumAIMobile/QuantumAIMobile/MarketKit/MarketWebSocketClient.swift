import Foundation

final class OneShotThrowingContinuation<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var pendingResult: Result<Value, Error>?

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        let pendingResult = lock.withLock { () -> Result<Value, Error>? in
            if let pendingResult = self.pendingResult {
                self.pendingResult = nil
                return pendingResult
            }

            guard self.continuation == nil else {
                return nil
            }

            self.continuation = continuation
            return nil
        }

        if let pendingResult {
            continuation.resume(with: pendingResult)
        }
    }

    func resume(with result: Result<Value, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Value, Error>? in
            if let continuation = self.continuation {
                self.continuation = nil
                return continuation
            }

            if self.pendingResult == nil {
                self.pendingResult = result
            }

            return nil
        }

        continuation?.resume(with: result)
    }
}

extension OneShotThrowingContinuation where Value == Void {
    func resume() {
        resume(with: .success(()))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

public final class MarketWebSocketClient {
    public static let shared = MarketWebSocketClient()

    private let stateLock = NSLock()
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var onDisconnect: ((Error?) -> Void)?
    private var pingTask: Task<Void, Never>?
    private var isDisconnecting = false
    private var activeConnectionID = UUID()

    private init() {
        self.session = Self.makeSession()
    }

    public func connect(url: URL, onMessage: @escaping (String) -> Void, onDisconnect: ((Error?) -> Void)? = nil) {
        disconnect()

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let connectionID = UUID()
        let task = stateLock.withLock { () -> URLSessionWebSocketTask in
            isDisconnecting = false
            self.onDisconnect = onDisconnect
            if session == nil {
                session = Self.makeSession()
            }

            activeConnectionID = connectionID
            let task = session!.webSocketTask(with: request)
            self.task = task
            return task
        }

        task.resume()
        startPingLoop(connectionID: connectionID, task: task)
        listen(connectionID: connectionID, task: task, onMessage: onMessage)
    }

    private func listen(connectionID: UUID, task: URLSessionWebSocketTask, onMessage: @escaping (String) -> Void) {
        task.receive { [weak self] result in
            guard let self, self.isActive(connectionID: connectionID, task: task) else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    onMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        onMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listen(connectionID: connectionID, task: task, onMessage: onMessage)
            case .failure(let error):
                self.handleDisconnect(error, connectionID: connectionID)
            }
        }
    }

    private func startPingLoop(connectionID: UUID, task: URLSessionWebSocketTask) {
        let previousPingTask = stateLock.withLock { () -> Task<Void, Never>? in
            let pingTask = self.pingTask
            self.pingTask = nil
            return pingTask
        }
        previousPingTask?.cancel()

        let newPingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, self.isActive(connectionID: connectionID, task: task) else { break }

                do {
                    try await self.sendPing(on: task)
                } catch {
                    guard !(error is CancellationError), self.isActive(connectionID: connectionID, task: task) else {
                        break
                    }

                    self.handleDisconnect(error, connectionID: connectionID)
                    break
                }
            }
        }

        let isCurrentConnection = stateLock.withLock { () -> Bool in
            guard !isDisconnecting, activeConnectionID == connectionID, self.task === task else {
                return false
            }

            pingTask = newPingTask
            return true
        }

        if !isCurrentConnection {
            newPingTask.cancel()
        }
    }

    private func sendPing(on task: URLSessionWebSocketTask) async throws {
        let continuation = OneShotThrowingContinuation<Void>()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (checkedContinuation: CheckedContinuation<Void, Error>) in
                continuation.install(checkedContinuation)
                task.sendPing { error in
                    if let error {
                        continuation.resume(with: .failure(error))
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: {
            continuation.resume(with: .failure(CancellationError()))
        }
    }

    private func handleDisconnect(_ error: Error?, connectionID: UUID) {
        let disconnectedState = stateLock.withLock { () -> (Task<Void, Never>?, URLSessionWebSocketTask?, ((Error?) -> Void)?)? in
            guard !isDisconnecting, activeConnectionID == connectionID else { return nil }

            isDisconnecting = true
            let pingTask = self.pingTask
            self.pingTask = nil
            let task = self.task
            self.task = nil
            let onDisconnect = self.onDisconnect
            self.onDisconnect = nil
            return (pingTask, task, onDisconnect)
        }

        guard let (pingTask, task, onDisconnect) = disconnectedState else { return }
        pingTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        onDisconnect?(error)
    }

    public func disconnect() {
        let disconnectedState = stateLock.withLock { () -> (Task<Void, Never>?, URLSessionWebSocketTask?, URLSession?) in
            isDisconnecting = true
            activeConnectionID = UUID()
            let pingTask = self.pingTask
            self.pingTask = nil
            onDisconnect = nil
            let task = self.task
            self.task = nil
            let session = self.session
            self.session = nil
            return (pingTask, task, session)
        }

        let (pingTask, task, session) = disconnectedState
        pingTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 86_400
        return URLSession(configuration: configuration)
    }

    private func isActive(connectionID: UUID, task: URLSessionWebSocketTask) -> Bool {
        stateLock.withLock {
            !isDisconnecting && activeConnectionID == connectionID && self.task === task
        }
    }
}
