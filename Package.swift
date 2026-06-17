// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Adhder",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Adhder",
            path: "Sources/Adhder"
        )
    ]
)
