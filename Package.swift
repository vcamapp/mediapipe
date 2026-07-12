// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaPipe",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MediaPipeTasksVision", targets: ["MediaPipeTasksVision"]),
        .library(
            name: "MediaPipeTasksVisionHandLandmarker",
            targets: ["MediaPipeTasksVisionHandLandmarker"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MediaPipeTasksVision",
            url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.3/MediaPipeTasksVision.xcframework.zip",
            checksum: "5764d256fa14d8cd45b483e7f5bdd91d6678a4b0aa940e96deb99e6bb4edc05c"
        ),
        .target(
            name: "MediaPipeTasksVisionHandLandmarker",
            dependencies: ["MediaPipeTasksVision"],
            resources: [.copy("Resources/Models")]
        )
    ]
)
