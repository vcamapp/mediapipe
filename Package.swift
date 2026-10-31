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
        url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.15/MediaPipeTasksVision.xcframework.zip",
        checksum: "5aa2bb44074e6d2f9d9277bda535173beedb4b138ea91bf8ad331fb43297aa2c"
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
        ),
        .library(
            name: "MediaPipeTasksVisionPoseLandmarker",
            targets: ["MediaPipeTasksVisionPoseLandmarker"]
        ),
        .library(
            name: "MediaPipeTasksVisionFaceLandmarker",
            targets: ["MediaPipeTasksVisionFaceLandmarker"]
        )
    ],
    targets: [
        mediaPipeTasksVision,
        .target(name: "MediaPipeTasksVisionSupport"),
        .target(
            name: "MediaPipeTasksVisionHandLandmarker",
            dependencies: ["MediaPipeTasksVision", "MediaPipeTasksVisionSupport"],
            resources: [.copy("Resources/Models")]
        ),
        .target(
            name: "MediaPipeTasksVisionPoseLandmarker",
            dependencies: ["MediaPipeTasksVision", "MediaPipeTasksVisionSupport"],
            resources: [.copy("Resources/Models")]
        ),
        .target(
            name: "MediaPipeTasksVisionFaceLandmarker",
            dependencies: ["MediaPipeTasksVision", "MediaPipeTasksVisionSupport"],
            resources: [.copy("Resources/Models")]
        ),
        .testTarget(
            name: "MediaPipeTasksVisionHandLandmarkerTests",
            dependencies: ["MediaPipeTasksVisionHandLandmarker"]
        ),
        .testTarget(
            name: "MediaPipeTasksVisionPoseLandmarkerTests",
            dependencies: ["MediaPipeTasksVisionPoseLandmarker"]
        ),
        .testTarget(
            name: "MediaPipeTasksVisionFaceLandmarkerTests",
            dependencies: ["MediaPipeTasksVisionFaceLandmarker"]
        )
    ]
)
