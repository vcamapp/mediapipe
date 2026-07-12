// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaPipe",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MediaPipeTasksVision", targets: ["MediaPipeTasksVision"])
    ],
    targets: [
        .binaryTarget(
            name: "MediaPipeTasksVision",
            url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.2/MediaPipeTasksVision.xcframework.zip",
            checksum: "585794bb9c34de4f5d7a5a8ae17d1c520875294b55a00716ffce41d8eb8a133f"
        )
    ]
)
