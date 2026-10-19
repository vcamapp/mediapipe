# Source build

Every slice of `MediaPipeTasksVision.xcframework` — iOS device, iOS simulator
and macOS — is built from source: upstream
[MediaPipe](https://github.com/google-ai-edge/mediapipe) plus the patches in
this directory produce one static library per platform
(`MediaPipeTasksVision_static.a`, arm64, XNNPACK CPU + Metal GPU delegate)
that the wrapper project links into the framework. Google ships no macOS
binaries, and its iOS binaries copy every camera frame on the CPU before
inference (see `patches/0009-…`); they are also built against Google's
internal Abseil and logging, so patched code cannot be linked into them.

This directory contains everything required to reproduce the libraries. The
prebuilt archives themselves are distributed through GitHub Releases (tag
`static-<MEDIAPIPE_VERSION>`, pinned by SHA-256 in `config/versions.env`)
because they are too large for git.

## Contents

| Path | Description |
|---|---|
| `Headers/` | Flattened public headers shared by every slice, generated from the patched sources (includes the `MPPImageOrientation` compatibility layer in `MPPImage.h`) |
| `patches/0001-…` | Build wiring: `macos_opencv` repointed at a statically built OpenCV (`third_party/opencv_static`), the `.bazelrc` additions (hermetic Python, Apple crosstool for `--config=macos`), `apple_cc_configure` exposed to the root module in MODULE.bazel so the `--crosstool_top` flags resolve, and the `absl/cleanup` include that the Metal path of `inference_runner_litert.cc` uses but upstream never declares |
| `patches/0003-…` | UIKit-independence for the Objective-C API. On iOS the public API is unchanged (`typedef UIImageOrientation MPPImageOrientation`); on macOS an `NS_ENUM` with identical cases and raw values is provided. `UIImage` APIs are guarded with `#if __has_include(<UIKit/UIKit.h>)`, and `BUILD` dependencies on UIKit are `select()`ed away for `//mediapipe:macos` |
| `patches/0004-…` | Adds `//mediapipe/tasks/ios:MediaPipeTasksVision_static`, an `objc_library` umbrella covering every vision task. The upstream `MediaPipeTasksCommon` framework cannot be built from the public sources (it depends on internal-only packages such as `text_proofreader`) |
| `patches/0005-…` | Optional smoke-test targets (C API and Objective-C API) |
| `patches/0006-…` | Opt-in FP16 inference for the XNNPACK delegate: `TFLITE_XNNPACK_DELEGATE_FLAG_FORCE_FP16` is added to the default delegate options only when `MEDIAPIPE_XNNPACK_FORCE_FP16=1` is set while the task builds its delegate. FP16 is ~1.8x faster on Apple Silicon (13.9 ms vs 25.9 ms per hand frame, landmark drift ≤1% of the normalized frame) but cannot be forced globally: the pose detector returns no detection at all in FP16 |
| `patches/0007-…` | Flushes the `CVOpenGLTextureCache` before each texture creation in `GpuBufferStorageCvPixelBuffer::GetTexture`. Unlike the iOS ES cache, the macOS cache never recycles entries on create and nothing flushes it outside the pixel-buffer-pool path, so the GPU delegate leaks ~2 IOSurfaces per frame (measured with `ioclasscount`) until `CVPixelBufferCreate` fails with `kCVReturnAllocationFailed` (-6662) and MediaPipe aborts after ~10 minutes (google-ai-edge/mediapipe/issues/5267, google-ai-edge/mediapipe/issues/5510) |
| `patches/0008-…` | `MPPPoseLandmarker` requests the `SEGMENTATION_MASK` output stream only when `shouldOutputSegmentationMasks` is set. The graph adds its mask branch based on that output, and both of the branch's calculators (`TensorsToSegmentationCalculator`, `WarpAffineCalculator`) compile GLSL 3.30 shaders, which the macOS NSOpenGL context (2.1, since MediaPipe only requests a 3.2 Core profile under `OSX_ENABLE_3_2_CORE`) rejects — the GPU delegate could not run pose at all |
| `patches/0009-…` | A BGRA `CVPixelBuffer` handed to a task (`MPImage` from a pixel buffer or sample buffer) enters the graph as a `GpuBuffer` wrapping the buffer itself. Upstream first copies it into an `ImageFrame` on the CPU (channel permutation + unpremultiply) and the graph's `ImageCloneCalculator` then copies that back into a new `CVPixelBuffer` to upload it; for an opaque camera frame the round trip was ~40% of the task's CPU time. On an iPhone 12 Pro Max, face landmarking took 4.7 ms instead of 8.7 ms per frame. The buffer must be IOSurface-backed (camera frames and pool buffers with `kCVPixelBufferIOSurfacePropertiesKey` are); other formats keep the `ImageFrame` path |
| `patches/0010-…` | Reverts upstream d59afd2 ("Fix GPU interactive segmentation on macOS"), which makes the macOS GPU buffer pool vend `GlTextureBuffer` instead of `CVPixelBuffer`. With it, `MPPFaceLandmarker` on the GPU delegate finds no face in any frame while hand and pose keep working; interactive segmentation, the only thing it fixes, is not part of the vision trackers this package targets. The revert brings back the `ImageFrame` → `CVPixelBuffer` conversion path, so `patches/0007-…` stays required |
| `patches/0011-…` | Statically built OpenCV for the iOS device and simulator builds (`ios_opencv_static` / `ios_simulator_opencv_static` at `third_party/opencv_ios_static` / `third_party/opencv_ios_simulator_static`) in place of `@ios_opencv_source`, whose OpenCV 4.5.3 framework build no longer configures with current Xcode and CMake, and a `--config=ios_sim_arm64` |
| `licenses/` | License texts for the libraries statically linked into the artifacts (OpenCV, libjpeg-turbo, libpng, libtiff, KleidiCV); bundled into each release's `THIRD_PARTY_NOTICES.txt` |
| `apply-patches.sh` | Applies a platform's patches to an upstream checkout. Patches named `*-macos-*` (0005, 0007, 0010) are applied to the macOS build only; the rest to every platform |
| `build-opencv.sh` | Builds the statically linked OpenCV for a platform |
| `build-static-lib.sh` | Builds a platform's `MediaPipeTasksVision_static.a` and the `Headers/` set from a patched checkout |

## Building the artifacts

### CI (recommended)

Run the **“Static libraries”** GitHub Actions workflow
(`.github/workflows/static-artifacts.yml`). For each platform in parallel it
checks out upstream MediaPipe at `v<MEDIAPIPE_VERSION>`, applies the
platform's patches, builds the static OpenCV (cached), builds the library and
uploads the zip to the `static-<MEDIAPIPE_VERSION>` release; a final job
commits the SHA-256 pins to `config/versions.env`.

### Locally

Requirements: Apple Silicon Mac, Xcode, `bazelisk`, `cmake`. `<platform>` is
`macos`, `ios` or `ios-simulator`; one checkout can build all three.

```bash
# 1. Check out upstream at the pinned tag and apply the platform's patches
git clone --branch "v$MEDIAPIPE_VERSION" https://github.com/google-ai-edge/mediapipe.git
path/to/source/apply-patches.sh <platform> mediapipe

# 2. Build static OpenCV once per platform
path/to/source/build-opencv.sh <platform> <work-dir> <opencv-prefix>

# 3. Build the static library and headers
path/to/source/build-static-lib.sh <platform> "$PWD/mediapipe" <opencv-prefix> <out-dir>
```

The Bazel invocations behind step 3 are `-c opt --apple_generate_dsym=false`
with `--config=darwin_arm64` (macOS) or
`--config=ios_arm64` / `--config=ios_sim_arm64` plus
`--ios_minimum_os=<MINIMUM_IOS_VERSION> --define=OPENCV=source` (iOS). If the
generated `<out-dir>/Headers/` differ from `Headers/` in this directory,
update the committed copy — the wrapper project compiles against it. To
package the libraries without downloading, zip each `MediaPipeTasksVision_static.a`
as `MediaPipeTasksVision-<platform>-arm64-<MEDIAPIPE_VERSION>.zip` into one
directory and run `make all` with `STATIC_ARTIFACT_DIR` pointing at it.

## Linking against the library

Used by `scripts/build.sh`; relevant when consuming the `.a` directly:

- `-Wl,-force_load,MediaPipeTasksVision_static.a -ObjC -lc++ -lz`
  — `-force_load` is required for the calculators' static registration, and
  `-ObjC` for Objective-C categories.
- Frameworks: Foundation, CoreFoundation, CoreGraphics, CoreVideo, CoreMedia,
  Accelerate, CoreImage, QuartzCore, AVFoundation, Metal, MetalKit,
  MetalPerformanceShaders, IOSurface, plus AppKit and OpenGL on macOS or
  UIKit and OpenGLES on iOS.
- OpenCV is embedded in the archive; no extra OpenCV link flags are needed.

## Static OpenCV notes

`build-opencv.sh` builds OpenCV (core/imgproc/imgcodecs only) with settings
that matter for correctness, not just size:

- `BUILD_ZLIB=OFF` — MediaPipe bundles its own zlib; a second copy causes
  duplicate symbols in the combined archive.
- Protobuf disabled — a second protobuf runtime in the process crashes at
  run time (observed with the dynamically linked Homebrew OpenCV, whose
  `videoio`/`dnn` modules pull one in).
- The OpenCV version must match the headers the Objective-C layer is compiled
  against (C++ ABI); it is pinned as `OPENCV_VERSION` in
  `config/versions.env`.
- iOS builds plain static libraries (`APPLE_FRAMEWORK=OFF`, no Objective-C
  bindings) at `MINIMUM_IOS_VERSION`.
- Output: `libopencv_{core,imgproc,imgcodecs}.a` plus bundled codec libraries.
  Linking requires `-framework Accelerate -lz` (and AppKit on macOS),
  propagated via the patched `opencv_macos.BUILD` / `opencv_ios_static.BUILD`.

## Known limitations

1. **The macOS runtime default is CPU (XNNPACK) inference.** The Metal
   delegate is opt-in per tracker via
   `HandLandmarkTrackingConfiguration.inferenceBackend = .gpu` (~5x lower CPU
   per inference; GPU landmarks drift up to 2.6% of the normalized frame vs
   CPU, and Google does not test this configuration on macOS).
2. `MPImage(uiImage:)` is unavailable on macOS; use `CVPixelBuffer` or
   `CMSampleBuffer`. Orientation is `UIImage.Orientation` on iOS and
   `MPImageOrientation` (same cases and raw values) on macOS.
3. The MediaPipe implementation is arm64 only. The x86_64 slice of the
   released macOS framework is the link-only stub from `builder/x86_64-stub`
   (built by `scripts/build-x86_64-stub.sh`), so MediaPipe never runs on
   Intel Macs or under Rosetta, and there is no x86_64 simulator slice.
4. The rewritten `MPPInteractiveSegmenter` introduced in v1.0.0 ships without
   a `BUILD` file upstream and is excluded from the umbrella target; every
   slice carries `MPPInteractiveSegmenterLegacy` instead. Only the vision
   tasks are built (no audio, text or retrieval APIs).
5. **Pose segmentation masks are unavailable on macOS.** With
   `shouldOutputSegmentationMasks = true` the graph builds the GL calculators
   described in `patches/0008-…`, which cannot compile their shaders in the
   macOS OpenGL 2.1 context. Landmarks are unaffected.
