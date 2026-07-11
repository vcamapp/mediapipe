# Builder

The `MediaPipeTasksVisionWrapper.xcodeproj` is generated/maintained on an
Apple Silicon build host after `make fetch`. It links the arm64 device and
simulator CocoaPods slices into the single dynamic framework. The checked-in
headers and force-link source define the public module surface.
