// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BRLCTMenuApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BRLCTMenuApp",
            path: "Sources/BRLCTMenuApp"
        )
    ]
)
