# Builder

The `MediaPipeTasksVisionWrapper.xcodeproj` is generated/maintained on an
Apple Silicon build host after `make fetch`. It links the arm64 device and
simulator CocoaPods slices into the single dynamic framework. The checked-in
headers and force-link source define the public module surface.

`x86_64-stub/` provides the link-only x86_64 slice of the macOS framework
(see its README); it is built by `scripts/build-x86_64-stub.sh` and merged
with the arm64 framework by `scripts/create-xcframework.sh`.
