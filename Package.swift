// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CatProtector",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CatProtector",
            path: "Sources/CatProtector"
        ),
        .testTarget(
            name: "CatProtectorTests",
            dependencies: ["CatProtector"],
            path: "Tests/CatProtectorTests"
        ),
    ]
)
