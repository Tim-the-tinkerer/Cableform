// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cableform",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Cableform", targets: ["Cableform"]),
    ],
    targets: [
        .executableTarget(
            name: "Cableform",
            path: "Sources/Cableform"
        ),
    ]
)
