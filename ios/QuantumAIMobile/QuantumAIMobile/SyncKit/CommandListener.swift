import Foundation

public enum RemoteCommand: String, Codable {
    case stopAllBots = "STOP_ALL"
    case emergencySell = "EMERGENCY_SELL"
    case resetVault = "RESET_VAULT"
}

private struct RemoteCommandEnvelope: Decodable {
    let command: RemoteCommand
}

public final class CommandListener {
    private weak var env: AppEnvironment?
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
            let (data, response) = try await URLSession.shared.data(from: RuntimeServiceConfig.commandsURL)
            if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                return
            }
            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(RemoteCommandEnvelope.self, from: data) {
                await execute(envelope.command)
                return
            }
            if let command = try? decoder.decode(RemoteCommand.self, from: data) {
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
            env.settings.licenseActivatedAt = .now
            env.audit.append(action: "remote.reset_vault", payload: [:])
        }
    }

    deinit {
        stopPolling()
    }
}
