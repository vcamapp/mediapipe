# Third-party notices

The iOS slices bundle Google's official MediaPipe Tasks Vision 1.1.1 binaries
(the binary targets of upstream's `Package.swift`). The MediaPipe license
from the same upstream tag is copied into each release's
`THIRD_PARTY_NOTICES.txt`.

The bundled dependency set includes MediaPipe, TensorFlow Lite, OpenCV, Abseil,
Protobuf, and other libraries required by the selected MediaPipe artifact where
present. This file describes the process; the release asset contains the exact
text distributed with the locked build.

## macOS slice

The `macos-arm64` slice is built from upstream MediaPipe 1.0.0 sources with
the patches in `macos/patches/` (see `macos/README.md`) rather than from the
official binaries. It statically links the same dependency set — MediaPipe,
TensorFlow Lite (XNNPACK), Abseil, Protobuf, glog, gflags, zlib and related
libraries — whose license texts are already covered by the MediaPipe notices
collected into each release's `THIRD_PARTY_NOTICES.txt`.

OpenCV 4.13.0 (core/imgproc/imgcodecs) is statically linked into the macOS
slice together with its bundled codec dependencies (libjpeg-turbo, libpng,
libtiff) and Arm KleidiCV. Their license texts live in `macos/licenses/`
and are appended to each release's `THIRD_PARTY_NOTICES.txt`.
