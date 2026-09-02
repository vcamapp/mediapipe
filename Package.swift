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
        url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.9/MediaPipeTasksVision.xcframework.zip",
        checksum: "d5fc302a0ccc9420dd132386026578c32899b63e7b81a94121386b0520ad9045"
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
