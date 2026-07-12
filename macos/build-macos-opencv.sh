#!/usr/bin/env bash
# Builds the statically linked OpenCV (core/imgproc/imgcodecs) that the macOS
# MediaPipe artifact links against. The resulting install prefix is referenced
# by the `macos_opencv` new_local_repository in the patched MediaPipe WORKSPACE.
#
# The OpenCV version must match the headers the ObjC layer is compiled
# against (ODR/ABI hazard otherwise); it defaults to OPENCV_VERSION from
# config/versions.env and can be overridden via the environment.
set -euo pipefail

if [[ -z "${OPENCV_VERSION:-}" ]]; then
  repo_versions="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/versions.env"
  [[ -f "$repo_versions" ]] && source "$repo_versions"
fi
OPENCV_VERSION="${OPENCV_VERSION:?OPENCV_VERSION is not set}"
work_dir="${1:?usage: $0 <work-dir> <install-prefix>}"
prefix="${2:?usage: $0 <work-dir> <install-prefix>}"

mkdir -p "$work_dir"
cd "$work_dir"
[[ -d "opencv-$OPENCV_VERSION" ]] || {
  curl -fL --retry 3 -o "opencv-$OPENCV_VERSION.tar.gz" \
    "https://github.com/opencv/opencv/archive/refs/tags/$OPENCV_VERSION.tar.gz"
  tar xzf "opencv-$OPENCV_VERSION.tar.gz"
}

mkdir -p build && cd build
# BUILD_ZLIB=OFF is required: MediaPipe already bundles its own zlib and a
# second copy inside the combined archive would cause duplicate symbols.
# Protobuf stays disabled to avoid clashing with MediaPipe's protobuf.
# The 11.0 deployment target is intentionally below MINIMUM_MACOS_VERSION:
# it matches the MediaPipe objects (10.16+) the archive is combined with.
cmake "../opencv-$OPENCV_VERSION" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_LIST=core,imgcodecs,imgproc \
  -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF \
  -DBUILD_opencv_apps=OFF -DBUILD_opencv_python3=OFF -DOPENCV_SKIP_PYTHON_LOADER=ON \
  -DWITH_ITT=OFF -DWITH_JASPER=OFF -DWITH_OPENCL=OFF -DWITH_WEBP=OFF \
  -DWITH_OPENEXR=OFF -DWITH_OPENJPEG=OFF -DWITH_PROTOBUF=OFF -DBUILD_PROTOBUF=OFF \
  -DWITH_FFMPEG=OFF -DWITH_OPENGL=OFF \
  -DWITH_JPEG=ON -DBUILD_JPEG=ON \
  -DWITH_PNG=ON -DBUILD_PNG=ON \
  -DWITH_TIFF=ON -DBUILD_TIFF=ON \
  -DBUILD_ZLIB=OFF \
  -DCV_ENABLE_INTRINSICS=ON -DWITH_EIGEN=OFF -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_INSTALL_PREFIX="$prefix"
make -j"$(sysctl -n hw.ncpu)" install

ls "$prefix/lib/libopencv_core.a" "$prefix/lib/opencv4/3rdparty" >/dev/null
echo "OK: static OpenCV installed to $prefix"
