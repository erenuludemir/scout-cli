// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuantumAIMobile",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuantumAIMobile", targets: ["QuantumAIMobile"])
    ],
    targets: [
        .target(
            name: "QuantumAIMobile",
            path: "QuantumAIMobile",
            exclude: [
                "Runbook",
                "AppShell/LoginView.swift",
                "AppShell/BinanceMasterPanel.swift",
                "AppShell/BursaOpsPanelView.swift",
                "AppShell/HedgeFundDashboardView.swift",
                "AppShell/OutboxListView.swift",
                "DesignSystem/OutboxAlertView.swift",
                "DesignSystem/PerformanceChart.swift",
                "StorageKit/AuditReportGenerator.swift",
                "StorageKit/IntegrityChecker.swift",
                "SyncKit/SyncClient.legacy.disabled",
                "SyncKit/SyncClient.legacy.disabled.SyncKit",
                "AlertKit/NotificationManager.swift"
            ],
            sources: [
                "AlertKit",
                "AppShell",
                "BotKit",
                "CoreKit",
                "DesignSystem",
                "MarketKit",
                "NetworkKit",
                "ObservabilityKit",
                "PropertyKit",
                "SecurityKit",
                "SettingsKit",
                "StorageKit",
                "Support",
                "SyncKit",
                "WalletKit"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("PRODUCTION", .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "QuantumAIMobileTests",
            dependencies: ["QuantumAIMobile"],
            path: "QuantumAIMobileTests"
        )
    ]
)
