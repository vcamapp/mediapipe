# Third-party notices

The release artifact bundles MediaPipe Tasks Vision 0.10.35 and its transitive
CocoaPods dependencies. The exact license and notice files discovered from the
locked Pod installation are copied into each release's `THIRD_PARTY_NOTICES.txt`.

The bundled dependency set includes MediaPipe, TensorFlow Lite, OpenCV, Abseil,
Protobuf, and other libraries required by the selected MediaPipe artifact where
present. This file describes the process; the release asset contains the exact
text distributed with the locked build.

## macOS slice

The `macos-arm64` slice is built from upstream MediaPipe sources with the
patches in `macos/patches/` (see `macos/README.md`) rather than from CocoaPods
binaries. It statically
links the same dependency set — MediaPipe, TensorFlow Lite (XNNPACK), Abseil,
Protobuf, glog, gflags, zlib and related libraries — whose license texts are
already covered by the CocoaPods notices collected into each release's
`THIRD_PARTY_NOTICES.txt`.

OpenCV 4.13.0 (core/imgproc/imgcodecs) is statically linked into the macOS
slice together with its bundled codec dependencies (libjpeg-turbo, libpng,
libtiff) and Arm KleidiCV. Their license texts live in `macos/licenses/`
and are appended to each release's `THIRD_PARTY_NOTICES.txt`.
