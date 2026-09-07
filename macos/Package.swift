// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Note",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Note",
            path: "Sources/Note"
        )
    ]
)
