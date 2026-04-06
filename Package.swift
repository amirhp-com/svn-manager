// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SVNManager",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SVNManager",
            path: "Sources/SVNManager"
        )
    ]
)
