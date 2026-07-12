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
            url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.1/MediaPipeTasksVision.xcframework.zip",
            checksum: "c7131a3512f8e8bbeea0bb4d426a054b38bd66e96e4c6f504626288bf046b013"
        )
    ]
)
