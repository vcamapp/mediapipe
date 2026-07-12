# MediaPipe Tasks Vision for Swift Package Manager

This repository builds a single dynamic `MediaPipeTasksVision.xcframework` for
iOS 17+, with `arm64` device and `arm64` simulator slices. CocoaPods is used only
by the builder; consumers use Swift Package Manager and `import MediaPipeTasksVision`.

## Requirements

- iOS 17 or later
- arm64 iOS devices
- arm64 iOS Simulator
- Xcode 16.4 or later

## Bundled MediaPipe Version

This package currently bundles MediaPipe Tasks Vision 0.10.21.

Binary artifacts are distributed through this repository's GitHub Releases.

## License

This project is licensed under the Apache License 2.0.

MediaPipe and bundled third-party dependencies remain subject to their
respective licenses. See `THIRD_PARTY_NOTICES.md` and the notices attached
to each GitHub Release.

Run `make all` on an Apple Silicon Mac with Xcode, Ruby/Bundler, and CocoaPods
available. This also runs the Swift Testing smoke test with a fixed Hand
Landmarker model and image on an available arm64 iOS Simulator. The generated
files are placed under `.build-artifacts/` and are not committed. The release
ZIP uses normalized metadata so repeated packaging produces the same checksum.
