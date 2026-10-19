#!/usr/bin/env bash
# Builds the statically linked OpenCV (core/imgproc/imgcodecs) that a static
# MediaPipe artifact links against. The resulting install prefix is referenced
# by a new_local_repository in the patched MediaPipe WORKSPACE (see
# build-static-lib.sh, which links it into the checkout).
#
# The OpenCV version must match the headers the ObjC layer is compiled
# against (ODR/ABI hazard otherwise); it defaults to OPENCV_VERSION from
# config/versions.env and can be overridden via the environment.
set -euo pipefail

repo_versions="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/versions.env"
if [[ -z "${OPENCV_VERSION:-}" || -z "${MINIMUM_IOS_VERSION:-}" ]]; then
  [[ -f "$repo_versions" ]] && source "$repo_versions"
fi
OPENCV_VERSION="${OPENCV_VERSION:?OPENCV_VERSION is not set}"
usage="usage: $0 <macos|ios|ios-simulator> <work-dir> <install-prefix>"
platform="${1:?$usage}"
work_dir="${2:?$usage}"
prefix="${3:?$usage}"

case "$platform" in
  # The 11.0 deployment target is intentionally below MINIMUM_MACOS_VERSION:
  # it matches the MediaPipe objects (10.16+) the archive is combined with.
  macos) platform_flags=(-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0) ;;
  ios | ios-simulator)
    sysroot=iphoneos
    [[ "$platform" == ios-simulator ]] && sysroot=iphonesimulator
    platform_flags=(
      -DCMAKE_SYSTEM_NAME=iOS
      -DCMAKE_OSX_SYSROOT="$sysroot"
      -DCMAKE_OSX_DEPLOYMENT_TARGET="${MINIMUM_IOS_VERSION:?MINIMUM_IOS_VERSION is not set}"
      # Plain static libraries, not opencv2.framework with its ObjC bindings.
      -DAPPLE_FRAMEWORK=OFF -DBUILD_opencv_objc=OFF
    )
    ;;
  *) echo "$usage" >&2; exit 1 ;;
esac

mkdir -p "$work_dir"
cd "$work_dir"
[[ -d "opencv-$OPENCV_VERSION" ]] || {
  curl -fL --retry 3 -o "opencv-$OPENCV_VERSION.tar.gz" \
    "https://github.com/opencv/opencv/archive/refs/tags/$OPENCV_VERSION.tar.gz"
  tar xzf "opencv-$OPENCV_VERSION.tar.gz"
}

mkdir -p "build-$platform" && cd "build-$platform"
# BUILD_ZLIB=OFF is required: MediaPipe already bundles its own zlib and a
# second copy inside the combined archive would cause duplicate symbols.
# Protobuf stays disabled to avoid clashing with MediaPipe's protobuf.
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
  "${platform_flags[@]}" \
  -DCMAKE_INSTALL_PREFIX="$prefix"
make -j"$(sysctl -n hw.ncpu)" install

ls "$prefix/lib/libopencv_core.a" "$prefix/lib/opencv4/3rdparty" >/dev/null
echo "OK: static OpenCV ($platform) installed to $prefix"
