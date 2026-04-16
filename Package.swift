// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoduPomodoro",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HoduPomodoro",
            path: "Sources/HoduPomodoro"
        )
    ]
)
