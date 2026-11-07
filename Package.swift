// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MSIDisplayControl",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MSIDisplayControl", targets: ["MSIDisplayControl"]),
        .library(name: "MSIDisplayKit", targets: ["MSIDisplayKit"]),
    ],
    targets: [
        .target(name: "MSIDisplayKit"),
        .executableTarget(name: "MSIDisplayControl", dependencies: ["MSIDisplayKit"]),
        .testTarget(name: "MSIDisplayKitTests", dependencies: ["MSIDisplayKit"]),
    ],
    swiftLanguageModes: [.v5]
)
