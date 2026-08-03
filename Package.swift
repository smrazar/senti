// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Senti",
    // Matches Stow. The panel and settings window use `.symbolEffect` variants and
    // `ScrollView` behaviours that landed in macOS 15.
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(name: "Senti", path: "Sources/Senti")
    ]
)
