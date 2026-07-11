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
            url: "https://github.com/vcamapp/mediapipe/releases/download/1.0.0/MediaPipeTasksVision.xcframework.zip",
            checksum: "5d5250332d927bb35da372a113045cc8b01df6295a8a4f47c88e4ff2a8fb95f3"
        )
    ]
)
