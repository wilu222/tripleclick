// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TripleClick",
    platforms: [.macOS(.v13)],
    targets: [
        // Swift 5 mode: the C callbacks use plain global state.
        .executableTarget(name: "TripleClick", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
