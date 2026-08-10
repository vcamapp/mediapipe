// swift-tools-version: 5.9
import PackageDescription

// Set MEDIAPIPE_XCFRAMEWORK_PATH (relative to the package root) to build
// against a locally built XCFramework instead of the released binary;
// scripts/smoke-test.sh uses this to validate unreleased artifacts.
let mediaPipeTasksVision: Target = if let path = Context.environment["MEDIAPIPE_XCFRAMEWORK_PATH"], !path.isEmpty {
    .binaryTarget(name: "MediaPipeTasksVision", path: path)
} else {
    .binaryTarget(
        name: "MediaPipeTasksVision",
        url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.8/MediaPipeTasksVision.xcframework.zip",
        checksum: "89d1c8feac557b1f5d9cc03b160d70809caf80dbc2a4a6194fc8e6ef2150ea5d"
    )
}

let package = Package(
    name: "MediaPipe",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MediaPipeTasksVision", targets: ["MediaPipeTasksVision"]),
        .library(
            name: "MediaPipeTasksVisionHandLandmarker",
            targets: ["MediaPipeTasksVisionHandLandmarker"]
        )
    ],
    targets: [
        mediaPipeTasksVision,
        .target(
            name: "MediaPipeTasksVisionHandLandmarker",
            dependencies: ["MediaPipeTasksVision"],
            resources: [.copy("Resources/Models")]
        ),
        .testTarget(
            name: "MediaPipeTasksVisionHandLandmarkerTests",
            dependencies: ["MediaPipeTasksVisionHandLandmarker"]
        )
    ]
)
