// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "GitTokCore", platforms: [.macOS(.v14), .iOS(.v18)], products: [.library(name: "GitTokCore", targets: ["GitTokCore"])], targets: [.target(name: "GitTokCore"), .testTarget(name: "GitTokCoreTests", dependencies: ["GitTokCore"], resources: [.copy("Fixtures")])])
