import SwiftUI
@available(iOS 17.0, macOS 14.0, *)

public struct AlertsView: View {
    @EnvironmentObject private var env: AppEnvironment

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // AlertService currently doesn't expose a list of alerts.
                // Show an empty state for now.
                Text("Şimdilik uyarı yok")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Uyarılar")
        }
    }
}

