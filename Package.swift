// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FretNote",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FretNote", targets: ["FretNoteApp"])],
    targets: [
        .target(name: "FretNoteCore"),
        .executableTarget(name: "FretNoteApp", dependencies: ["FretNoteCore"]),
        .testTarget(name: "FretNoteCoreTests", dependencies: ["FretNoteCore"]),
        .testTarget(name: "FretNoteAppTests", dependencies: ["FretNoteApp", "FretNoteCore"])
    ]
)
