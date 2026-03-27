import SwiftUI

public struct CommandCenterView: View {
    @State private var scanPulse = false
    @State private var report = BursaHealthCheck.shared.performFullScan()

    public init() {}

    public var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(QAITheme.success.opacity(0.3), lineWidth: 2)
                    .scaleEffect(scanPulse ? 1.2 : 1.0)
                    .opacity(scanPulse ? 0 : 1)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(QAITheme.success)
            }
            .frame(width: 100, height: 100)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                    scanPulse = true
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                CommandCenterDiagnosticRow(name: "BURSA SENTINEL", status: report.sentinelOK ? "MUHURLU" : "ALARM", color: report.sentinelOK ? QAITheme.success : QAITheme.error)
                CommandCenterDiagnosticRow(name: "AI ORACLE (30S)", status: report.oracleOK ? "SENKRONIZE" : "KOPUK", color: report.oracleOK ? QAITheme.success : QAITheme.error)
                CommandCenterDiagnosticRow(name: "QUANTUM LEDGER", status: report.ledgerOK ? "DOGRULANDI" : "HATA", color: report.ledgerOK ? QAITheme.success : QAITheme.error)
                CommandCenterDiagnosticRow(name: "PARTNER VAULT", status: report.vaultOK ? "STANDBY" : "KAPALI", color: report.vaultOK ? QAITheme.panelBlue : QAITheme.error)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            PrimaryButton(title: "Full Scan Yeniden Calistir") {
                report = BursaHealthCheck.shared.performFullScan()
            }
        }
        .padding()
        .navigationTitle("Command Center")
    }
}

private struct CommandCenterDiagnosticRow: View {
    let name: String
    let status: String
    let color: Color

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(QAITheme.textSecondary)
            Spacer()
            Text(status)
                .font(.caption2)
                .bold()
                .foregroundStyle(color)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }
}
