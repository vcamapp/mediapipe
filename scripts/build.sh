#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
project="$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVisionWrapper.xcodeproj"
[[ -d "$project" ]] || { echo "Wrapper Xcode project is not present; generate it before building." >&2; exit 1; }
mkdir -p "$root_dir/.build-artifacts/archives"
static_root="$root_dir/.build-artifacts/static"
headers="$root_dir/source/Headers"

static_library() {
  local library="$static_root/$1/MediaPipeTasksVision_static.a"
  [[ -f "$library" ]] || { echo "$1 static library not fetched; run scripts/fetch.sh first." >&2; exit 1; }
  echo "$library"
}

copy_headers() {
  local headers_dir="$1" umbrella="$2"
  mkdir -p "$headers_dir"
  cp "$umbrella" "$headers_dir/MediaPipeTasksVision.h"
  find "$headers" -maxdepth 1 -type f -name '*.h' ! -name 'MediaPipeTasksVision.h' -exec cp {} "$headers_dir/" \;
}

build_ios() {
  local destination="$1" archive="$2" platform="$3"
  local static_lib
  static_lib=$(static_library "$platform")
  # The wrapper target links the rest of the system frameworks (generate-wrapper-project.rb).
  local flags="-ObjC -lc++ -lz -force_load $static_lib -framework MetalPerformanceShaders -framework IOSurface"
  xcodebuild archive -project "$project" -scheme MediaPipeTasksVision -configuration Release -destination "$destination" -archivePath "$root_dir/.build-artifacts/archives/$archive" ARCHS=arm64 EXCLUDED_ARCHS=x86_64 IPHONEOS_DEPLOYMENT_TARGET="$MINIMUM_IOS_VERSION" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO OTHER_LDFLAGS="$flags"
  local framework="$root_dir/.build-artifacts/archives/$archive.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework"
  copy_headers "$framework/Headers" "$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVision/MediaPipeTasksVision.h"
}

build_macos() {
  local archive="MediaPipeTasksVision-macOS"
  local static_lib
  static_lib=$(static_library macos)
  local flags="-ObjC -lc++ -lz -force_load $static_lib -framework Metal -framework MetalKit -framework MetalPerformanceShaders -framework OpenGL -framework IOSurface -framework CoreVideo"
  xcodebuild archive -project "$project" -scheme MediaPipeTasksVisionMac -configuration Release -destination 'generic/platform=macOS' -archivePath "$root_dir/.build-artifacts/archives/$archive" ARCHS=arm64 MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS_VERSION" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO OTHER_LDFLAGS="$flags"
  local framework="$root_dir/.build-artifacts/archives/$archive.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework"
  copy_headers "$framework/Versions/A/Headers" "$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVisionMac/MediaPipeTasksVision.h"
  ln -sfn Versions/Current/Headers "$framework/Headers"
}

build_ios 'generic/platform=iOS' MediaPipeTasksVision-iOS ios
build_ios 'generic/platform=iOS Simulator' MediaPipeTasksVision-Simulator ios-simulator
build_macos
