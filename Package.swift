// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TrekkHelper",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .executable(name: "TrekkHelper", targets: ["TrekkHelper"])
    ],
    targets: [
        .executableTarget(
            name: "TrekkHelper",
            dependencies: [],
            path: "Sources/TrekkHelper",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TrekkHelperTests",
            dependencies: ["TrekkHelper"],
            path: "Tests/TrekkHelperTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
