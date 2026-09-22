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
        url: "https://github.com/vcamapp/mediapipe/releases/download/0.0.11/MediaPipeTasksVision.xcframework.zip",
        checksum: "0e5b8715bf281ecdee3abb439cae912d9bde2eeff977d4f8f10a6fc89a6bb4ba"
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
