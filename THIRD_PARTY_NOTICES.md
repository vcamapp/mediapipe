# Third-party notices

Every slice (iOS device, iOS simulator, macOS) is built from upstream
MediaPipe 1.1.1 sources with the patches in `source/patches/` (see
`source/README.md`). The MediaPipe license from the same upstream tag is
copied into each release's `THIRD_PARTY_NOTICES.txt`.

The slices statically link MediaPipe and its dependency set — TensorFlow
Lite (XNNPACK and the Metal delegate), Abseil, Protobuf, glog, gflags, zlib
and related libraries — whose license texts are covered by the MediaPipe
notices collected into each release's `THIRD_PARTY_NOTICES.txt`. This file
describes the process; the release asset contains the exact text distributed
with the locked build.

OpenCV 4.13.0 (core/imgproc/imgcodecs) is statically linked into every slice
together with its bundled codec dependencies (libjpeg-turbo, libpng, libtiff)
and, where the platform build includes it, Arm KleidiCV. Their license texts
live in `source/licenses/` and are appended to each release's
`THIRD_PARTY_NOTICES.txt`.
