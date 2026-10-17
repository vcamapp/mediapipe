#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
project="$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVisionWrapper.xcodeproj"
[[ -d "$project" ]] || { echo "Wrapper Xcode project is not present; generate it before building." >&2; exit 1; }
mkdir -p "$root_dir/.build-artifacts/archives"
ios_root="$root_dir/.build-artifacts/ios"

build_one() {
  local destination="$1" archive="$2" slice="$3"
  local vision="$ios_root/MediaPipeTasksVision.xcframework/$slice"
  local common="$ios_root/MediaPipeTasksCommon.xcframework/$slice"
  local graph="$ios_root/MediaPipeTaskGraphs_library.xcframework/$slice/MediaPipeTaskGraphs_library.a"
  [[ -d "$common/MediaPipeTasksCommon.framework" && -f "$graph" ]] || { echo "Upstream binaries lack the $slice slice; run scripts/fetch.sh first." >&2; exit 1; }
  # MediaPipeTasksVision.framework upstream only carries the headers; every
  # task's Objective-C API lives in the static MediaPipeTasksCommon, so -ObjC
  # also pulls in the retrieval tasks and their SQLite vector store.
  local flags="-ObjC -lc++ -lz -lsqlite3 -force_load $graph -framework MediaPipeTasksCommon -framework AudioToolbox -framework CoreAudio"
  xcodebuild archive -project "$project" -scheme MediaPipeTasksVision -configuration Release -destination "$destination" -archivePath "$root_dir/.build-artifacts/archives/$archive" ARCHS=arm64 EXCLUDED_ARCHS=x86_64 IPHONEOS_DEPLOYMENT_TARGET="$MINIMUM_IOS_VERSION" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO FRAMEWORK_SEARCH_PATHS="$common" HEADER_SEARCH_PATHS="$vision/MediaPipeTasksVision.framework/Headers" OTHER_LDFLAGS="$flags"
  local framework="$root_dir/.build-artifacts/archives/$archive.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework"
  mkdir -p "$framework/Headers"
  cp "$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVision/MediaPipeTasksVision.h" "$framework/Headers/MediaPipeTasksVision.h"
  find "$vision/MediaPipeTasksVision.framework/Headers" -maxdepth 1 -type f -name '*.h' ! -name 'MediaPipeTasksVision.h' -exec cp {} "$framework/Headers/" \;
}

build_macos() {
  local archive="MediaPipeTasksVision-macOS"
  local static_lib="$root_dir/.build-artifacts/macos/MediaPipeTasksVision_macos.a"
  [[ -f "$static_lib" ]] || { echo "macOS static library not fetched; run scripts/fetch.sh first." >&2; exit 1; }
  # OpenCV (core/imgproc/imgcodecs) is statically linked inside the artifact.
  local flags="-ObjC -lc++ -lz -force_load $static_lib -framework Metal -framework MetalKit -framework MetalPerformanceShaders -framework OpenGL -framework IOSurface -framework CoreVideo"
  xcodebuild archive -project "$project" -scheme MediaPipeTasksVisionMac -configuration Release -destination 'generic/platform=macOS' -archivePath "$root_dir/.build-artifacts/archives/$archive" ARCHS=arm64 MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS_VERSION" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO OTHER_LDFLAGS="$flags"
  local framework="$root_dir/.build-artifacts/archives/$archive.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework"
  mkdir -p "$framework/Versions/A/Headers"
  cp "$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVisionMac/MediaPipeTasksVision.h" "$framework/Versions/A/Headers/MediaPipeTasksVision.h"
  find "$root_dir/macos/Headers" -maxdepth 1 -type f -name '*.h' ! -name 'MediaPipeTasksVision.h' -exec cp {} "$framework/Versions/A/Headers/" \;
  # Xcode only creates the top-level Headers symlink when headers are installed
  # during the archive; ours are copied in afterwards.
  ln -sfn Versions/Current/Headers "$framework/Headers"
}

vision_xcframework="$ios_root/MediaPipeTasksVision.xcframework"
simulator_slice=$(ruby -rjson -e '
  info = JSON.parse(`plutil -convert json -o - -- #{ARGV[0]}`)
  library = info.fetch("AvailableLibraries").find do |candidate|
    candidate["SupportedPlatform"] == "ios" &&
      candidate["SupportedPlatformVariant"] == "simulator" &&
      candidate.fetch("SupportedArchitectures", []).include?("arm64")
  end
  puts library.fetch("LibraryIdentifier") if library
' "$vision_xcframework/Info.plist")
[[ -n "$simulator_slice" ]] || { echo "No arm64 iOS Simulator slice found in $vision_xcframework" >&2; exit 1; }
build_one 'generic/platform=iOS' MediaPipeTasksVision-iOS ios-arm64
build_one 'generic/platform=iOS Simulator' MediaPipeTasksVision-Simulator "$simulator_slice"
build_macos
