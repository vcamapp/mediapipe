# MediaPipe Tasks Vision for Swift Package Manager

This repository builds a single dynamic `MediaPipeTasksVision.xcframework` for
iOS 17+, with `arm64` device and `arm64` simulator slices. CocoaPods is used only
by the builder; consumers use Swift Package Manager and `import MediaPipeTasksVision`.

## Requirements

- iOS 17 or later
- arm64 iOS devices
- arm64 iOS Simulator
- Xcode 16.4 or later

The optional `MediaPipeTasksVisionHandLandmarker` product includes the standard
Hand Landmarker model and provides `HandLandmarkerModel.url` and
`HandLandmarkerModel.makeOptions(runningMode:)` so applications do not need to
locate the model through `Bundle.module`.

## License

This project is licensed under the Apache License 2.0.

MediaPipe and bundled third-party dependencies remain subject to their
respective licenses. See `THIRD_PARTY_NOTICES.md` and the notices attached
to each GitHub Release.
