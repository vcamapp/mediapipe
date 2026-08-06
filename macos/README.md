# macOS support

Google does not publish macOS binaries of MediaPipe Tasks Vision — the
official CocoaPods are iOS-only. The macOS slice of
`MediaPipeTasksVision.xcframework` is therefore built from source: upstream
[MediaPipe](https://github.com/google-ai-edge/mediapipe) plus the patches in
this directory produce a single static library
(`MediaPipeTasksVision_macos.a`, arm64, XNNPACK CPU + Metal GPU delegate)
that the wrapper project links into the framework.

This directory contains everything required to reproduce that library. The
prebuilt archive itself is distributed through GitHub Releases (tag
`macos-<MEDIAPIPE_VERSION>`, pinned by URL and SHA-256 in
`config/versions.env`) because it is too large for git.

## Contents

| Path | Description |
|---|---|
| `Headers/` | Flattened public headers for the macOS framework slice, generated from the patched sources (includes the `MPPImageOrientation` compatibility layer in `MPPImage.h`) |
| `patches/0001-…` | Build wiring for the macOS static library: `macos_opencv` repointed at a statically built OpenCV (`third_party/opencv_static`), the `.bazelrc` additions (hermetic Python, Apple crosstool for `--config=macos`), and MODULE.bazel fixes for bzlmod — `apple_support` declared before `rules_cc` so its CC toolchain wins objc toolchain resolution, plus `apple_cc_configure` exposed to the root module so the `--crosstool_top` flags resolve. (The zlib/apple_support/rules_apple fixes the pre-1.0.0 patch carried are upstream now.) |
| `patches/0003-…` | UIKit-independence for the Objective-C API. On iOS the public API is unchanged (`typedef UIImageOrientation MPPImageOrientation`); on macOS an `NS_ENUM` with identical cases and raw values is provided. `UIImage` APIs are guarded with `#if __has_include(<UIKit/UIKit.h>)`, and `BUILD` dependencies on UIKit are `select()`ed away for `//mediapipe:macos` |
| `patches/0004-…` | Adds `//mediapipe/tasks/ios:MediaPipeTasksVision_macos`, an `objc_library` umbrella covering every vision task |
| `patches/0005-…` | Optional smoke-test targets (C API and Objective-C API) |
| `patches/0006-…` | FP16 inference for the XNNPACK delegate (`TFLITE_XNNPACK_DELEGATE_FLAG_FORCE_FP16` in the default delegate options; ~1.8x faster on Apple Silicon, measured landmark drift ≤1% of the normalized frame) |
| `licenses/` | License texts for the libraries statically linked into the macOS artifact (OpenCV, libjpeg-turbo, libpng, libtiff, KleidiCV); bundled into each release's `THIRD_PARTY_NOTICES.txt` |
| `build-macos-opencv.sh` | Builds the statically linked OpenCV that the artifact embeds |
| `build-macos-static-lib.sh` | Builds `MediaPipeTasksVision_macos.a` and the `Headers/` set from a patched checkout |

## Building the artifact

### CI (recommended)

Run the **“macOS build dependency”** GitHub Actions workflow
(`.github/workflows/macos-artifact.yml`). It checks out upstream MediaPipe at
`v<MEDIAPIPE_VERSION>`, applies `patches/`, builds the static OpenCV (cached),
builds the library, uploads the zip to the `macos-<MEDIAPIPE_VERSION>`
release, and prints the SHA-256 to set as `MACOS_ARTIFACT_SHA256` in
`config/versions.env`.

### Locally

Requirements: Apple Silicon Mac, Xcode, `bazelisk`, `cmake`.

```bash
# 1. Check out upstream at the pinned tag and apply the patches
git clone --branch "v$MEDIAPIPE_VERSION" https://github.com/google-ai-edge/mediapipe.git
cd mediapipe && git apply path/to/macos/patches/*.patch

# 2. Build static OpenCV once and link it into the checkout
path/to/macos/build-macos-opencv.sh <work-dir> <install-prefix>
ln -s <install-prefix> third_party/opencv_static

# 3. Build the static library and headers
path/to/macos/build-macos-static-lib.sh "$PWD" <out-dir>
```

The Bazel invocation behind step 3 is:
`-c opt --config=darwin_arm64 --apple_generate_dsym=false` (GPU enabled).
If the generated `<out-dir>/Headers/` differ from `Headers/` in this
directory, update the committed copy — the wrapper project compiles against
it.

## Linking against the library

Used by `scripts/build.sh`; relevant when consuming the `.a` directly:

- `-Wl,-force_load,MediaPipeTasksVision_macos.a -ObjC -lc++ -lz`
  — `-force_load` is required for the calculators' static registration, and
  `-ObjC` for Objective-C categories.
- Frameworks: Foundation, CoreFoundation, CoreGraphics, CoreVideo, CoreMedia,
  Accelerate, AppKit, CoreImage, QuartzCore, AVFoundation, Metal, MetalKit,
  MetalPerformanceShaders, OpenGL, IOSurface
  (UIKit / OpenGLES / AssetsLibrary are not needed).
- OpenCV is embedded in the archive; no extra OpenCV link flags are needed.

## Static OpenCV notes

`build-macos-opencv.sh` builds OpenCV (core/imgproc/imgcodecs only) with
settings that matter for correctness, not just size:

- `BUILD_ZLIB=OFF` — MediaPipe bundles its own zlib; a second copy causes
  duplicate symbols in the combined archive.
- Protobuf disabled — a second protobuf runtime in the process crashes at
  run time (observed with the dynamically linked Homebrew OpenCV, whose
  `videoio`/`dnn` modules pull one in).
- The OpenCV version must match the headers the Objective-C layer is compiled
  against (C++ ABI); it is pinned as `OPENCV_VERSION` in
  `config/versions.env`.
- Output: `libopencv_{core,imgproc,imgcodecs}.a` plus bundled codec libraries
  (libjpeg-turbo, libpng, libtiff, KleidiCV). Linking requires
  `-framework Accelerate -framework AppKit -lz`, propagated via the patched
  `opencv_macos.BUILD`.

## Known limitations

1. **The runtime default is still CPU (XNNPACK) inference.** The build is
   GPU-enabled (possible since MediaPipe 1.0.0 defines
   `MEDIAPIPE_GPU_BUFFER_USE_CV_PIXEL_BUFFER` for all Apple targets) and the
   Metal delegate is opt-in per tracker via
   `HandLandmarkTrackingConfiguration.inferenceBackend = .gpu` (~5x lower CPU
   per inference; GPU landmarks drift up to 2.6% of the normalized frame vs
   CPU, and Google does not test this configuration on macOS).
2. `MPImage(uiImage:)` is unavailable on macOS; use `CVPixelBuffer` or
   `CMSampleBuffer`. Orientation is `UIImage.Orientation` on iOS and
   `MPImageOrientation` (same cases and raw values) on macOS.
3. The MediaPipe implementation is arm64 only. The x86_64 slice of the
   released framework is the link-only stub from `builder/x86_64-stub`
   (built by `scripts/build-x86_64-stub.sh`), so MediaPipe never runs on
   Intel Macs or under Rosetta. Building the real implementation with
   `--cpu=darwin_x86_64` has not been verified.
4. The rewritten `MPPInteractiveSegmenter` introduced in v1.0.0 ships without
   a `BUILD` file upstream and is excluded from the umbrella target; the
   macOS slice carries `MPPInteractiveSegmenterLegacy` instead.
