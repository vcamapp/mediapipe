# Smoke test

The smoke test imports `MediaPipeTasksVision`, instantiates the Face, Hand, and
Pose options types, and runs a fixed-image Hand Landmarker inference on an
arm64 iOS Simulator. It uses Swift Testing (`@Test`, `#expect`, and `#require`),
not XCTest. UI and camera handling are intentionally out of scope.
