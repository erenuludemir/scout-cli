import Foundation

public enum RemoteCommand: String, Codable {
    case stopAllBots = "STOP_ALL"
    case emergencySell = "EMERGENCY_SELL"
    case resetVault = "RESET_VAULT"
}

public final class CommandListener {
    private weak var env: AppEnvironment?
    private let commandURL = URL(string: "https://example.invalid/v1/commands")!
    private var timer: Timer?

    public init(env: AppEnvironment) {
        self.env = env
    }

    public func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { await self?.checkForCommands() }
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func checkForCommands() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: commandURL)
            if let command = try? JSONDecoder().decode(RemoteCommand.self, from: data) {
                await execute(command)
            }
        } catch {}
    }

    @MainActor
    private func execute(_ command: RemoteCommand) async {
        guard let env else { return }
        env.audit.append(action: "remote.command_received", payload: ["cmd": command.rawValue])

        switch command {
        case .stopAllBots:
            env.bot.stopDCA()
            env.bot.stopGrid()
            env.copyTrade.stop()
        case .emergencySell:
            env.audit.append(action: "remote.emergency_sell", payload: [:])
        case .resetVault:
            env.settings.isAuthenticated = false
            env.audit.append(action: "remote.reset_vault", payload: [:])
        }
    }

    deinit {
        stopPolling()
    }
}
