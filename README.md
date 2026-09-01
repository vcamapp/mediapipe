# VCam MediaPipe Tasks Vision

An unofficial Swift Package Manager distribution of [Google MediaPipe Tasks Vision](https://github.com/google-ai-edge/mediapipe) for iOS and macOS.

The package provides:

- `MediaPipeTasksVision`
  - MediaPipe Tasks Vision XCFramework
- `MediaPipeTasksVisionHandLandmarker`
  - The standard Hand Landmarker model and helpers for creating `HandLandmarkerOptions`
- `MediaPipeTasksVisionPoseLandmarker`
  - The Pose Landmarker (lite) model and helpers for creating `PoseLandmarkerOptions`

## Requirements

- iOS 17 or later / macOS 14 or later
- arm64 iOS devices/simulators
- macOS: universal (arm64 + x86_64) linking, but MediaPipe inference runs
  only when executing natively on Apple Silicon — see
  [Intel Macs and Rosetta](#intel-macs-and-rosetta-x86_64)
- Xcode 26.x or later

## Installation

You can install this package with Swift Package Manager.

Select one of the following products:

| Product | Description |
|---|---|
| `MediaPipeTasksVision` | MediaPipe Tasks Vision APIs only |
| `MediaPipeTasksVisionHandLandmarker` | APIs and the bundled Hand Landmarker model |
| `MediaPipeTasksVisionPoseLandmarker` | APIs and the bundled Pose Landmarker model |

Select a landmarker product when using the model it bundles; the products can be
used together.

## Hand Landmarker

### Create a Hand Landmarker

The bundled product includes `hand_landmarker.task`. Applications do not need
to copy the model, locate it with `Bundle.module`, or manage its checksum.

```swift
import MediaPipeTasksVision
import MediaPipeTasksVisionHandLandmarker

let options = try HandLandmarkerModel.makeOptions(
    runningMode: .image,
    numberOfHands: 2
)

let handLandmarker = try HandLandmarker(options: options)
```

### Detect hands in a UIImage (iOS)

```swift
import MediaPipeTasksVision
import MediaPipeTasksVisionHandLandmarker
import UIKit

func detectHands(in image: UIImage) throws -> HandLandmarkerResult {
    let options = try HandLandmarkerModel.makeOptions(
        runningMode: .image
    )

    let handLandmarker = try HandLandmarker(options: options)
    let mpImage = try MPImage(uiImage: image)

    return try handLandmarker.detect(image: mpImage)
}
```

Each detected hand contains 21 normalized landmarks, world landmarks, and handedness information.

### Detect hands in a CVPixelBuffer (iOS / macOS)

On macOS there is no `UIImage`; wrap a `CVPixelBuffer` (for example the output
of a camera capture or an `NSImage` rendered into a BGRA buffer) instead:

```swift
import MediaPipeTasksVision
import MediaPipeTasksVisionHandLandmarker

func detectHands(in pixelBuffer: CVPixelBuffer) throws -> HandLandmarkerResult {
    let options = try HandLandmarkerModel.makeOptions(
        runningMode: .image
    )

    let handLandmarker = try HandLandmarker(options: options)
    let mpImage = try MPImage(pixelBuffer: pixelBuffer)

    return try handLandmarker.detect(image: mpImage)
}
```

### Live stream mode

Set the delegate before creating the `HandLandmarker`.

```swift
let options = try HandLandmarkerModel.makeOptions(
    runningMode: .liveStream,
    numberOfHands: 2
)

options.handLandmarkerLiveStreamDelegate = delegate

let handLandmarker = try HandLandmarker(options: options)
```

Send frames with monotonically increasing timestamps:

```swift
try handLandmarker.detectAsync(
    image: mpImage,
    timestampInMilliseconds: timestamp
)
```

When using `CVPixelBuffer` or `CMSampleBuffer`, the underlying pixel format must be `kCVPixelFormatType_32BGRA`.

### Access the bundled model

The model URL can be obtained directly when custom options are needed:

```swift
let modelURL = try HandLandmarkerModel.url

let options = HandLandmarkerOptions()
options.baseOptions.modelAssetPath = modelURL.path
options.runningMode = .video
options.numHands = 2
```

Model metadata is also available:

```swift
let metadata = try HandLandmarkerModel.metadata()

print(metadata.modelVersion)
print(metadata.testedMediaPipeVersion)
print(metadata.sha256)
```

## Pose Landmarker

### Create a Pose Landmarker

The bundled product includes `pose_landmarker_lite.task` (33 landmarks,
BlazePose GHUM).

```swift
import MediaPipeTasksVision
import MediaPipeTasksVisionPoseLandmarker

let options = try PoseLandmarkerModel.makeOptions(
    runningMode: .video,
    numberOfPoses: 1
)

let poseLandmarker = try PoseLandmarker(options: options)
```

Frames are supplied exactly like the Hand Landmarker: `MPImage(pixelBuffer:)`
on both platforms, `MPImage(uiImage:)` on iOS, and `detectAsync` with a
delegate in live stream mode.

### Pose tracking without MediaPipe types

```swift
import MediaPipeTasksVisionPoseLandmarker

guard MediaPipePoseTrackingSupport.isAvailable else {
    // Fall back to another implementation (e.g. Vision).
    return
}

let tracker = try MediaPipePoseTrackingFactory.makeTracker(
    configuration: PoseLandmarkTrackingConfiguration(numberOfPoses: 1)
)

let result = try tracker.detect(in: pixelBuffer, timestampInMilliseconds: timestamp)
for pose in result.poses {
    print(pose.landmarks.count, pose.worldLandmarks.count, pose.visibilities.count)
}
```

The tracker keeps the CPU delegate in full precision and leaves segmentation
masks off — see [macOS notes](#macos-notes) for why both matter there.

## Using a custom model

Use the `MediaPipeTasksVision` product and provide an absolute path to your
model file:

```swift
import MediaPipeTasksVision

let options = HandLandmarkerOptions()
options.baseOptions.modelAssetPath = modelURL.path
options.runningMode = .image
options.numHands = 2

let handLandmarker = try HandLandmarker(options: options)
```

## Hand tracking without MediaPipe types

`MediaPipeTasksVisionHandLandmarker` also provides a tracker API that hides
every MediaPipe type behind package-defined value types, which keeps app
binaries free of MediaPipe symbol references outside this package:

```swift
import MediaPipeTasksVisionHandLandmarker

guard MediaPipeHandTrackingSupport.isAvailable else {
    // Fall back to another implementation (e.g. Vision).
    return
}

let tracker = try MediaPipeHandTrackingFactory.makeTracker(
    configuration: HandLandmarkTrackingConfiguration(numberOfHands: 2)
)

let result = try tracker.detect(in: pixelBuffer, timestampInMilliseconds: timestamp)
for hand in result.hands {
    print(hand.handedness, hand.landmarks.count)
}
```

## macOS notes

The macOS slice is built from upstream MediaPipe sources plus the patches in
[`macos/`](macos/README.md) (Google does not ship macOS binaries):

- Inference runs on the CPU (XNNPACK) by default; the Metal GPU delegate is
  opt-in per tracker.
- The CPU delegate runs models in full precision unless a task opts into FP16
  through `MEDIAPIPE_XNNPACK_FORCE_FP16=1`. The bundled hand tracker opts in
  (~1.8x faster, ~1% landmark drift); the pose tracker must not, because its
  detector stops producing detections in FP16.
- Pose segmentation masks are unavailable: the mask branch of the graph uses
  shaders that the macOS OpenGL context (2.1) rejects, so `PoseLandmarker` is
  only created with `shouldOutputSegmentationMasks = false`.

### Intel Macs and Rosetta (x86_64)

The macOS framework is universal so that universal apps can link and launch
everywhere, but only the arm64 slice contains MediaPipe. The x86_64 slice is
a link-only stub: every class exists for the linker and dyld, task
initializers report an error, and any other use raises
`MPPUnsupportedArchitectureException`.

Check `MediaPipeHandTrackingSupport.isAvailable` (or, when using the raw
APIs, guard with `#if arch(arm64)`) before creating MediaPipe objects. The
check reflects the executing binary slice, so it is also `false` on Apple
Silicon Macs when the app runs under Rosetta.

## License

This project is licensed under the Apache License 2.0.

MediaPipe, the bundled Hand Landmarker model, and bundled third-party
dependencies remain subject to their respective licenses and notices.

See:

- [`LICENSE`](LICENSE)
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

