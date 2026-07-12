#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVisionWrapper.xcodeproj"
[[ -d "$project" ]] || { echo "Wrapper Xcode project is not present; generate it before building." >&2; exit 1; }
mkdir -p "$root_dir/.build-artifacts/archives"
pod_root="$root_dir/builder/Pods"
build_one() {
  local platform="$1" destination="$2" archive="$3" slice="$4"
  local vision="$pod_root/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework/$slice"
  local common="$pod_root/MediaPipeTasksCommon/frameworks/MediaPipeTasksCommon.xcframework/$slice"
  local graph_platform="device"; [[ "$platform" == iphonesimulator ]] && graph_platform="simulator"
  local graph="$pod_root/MediaPipeTasksCommon/frameworks/graph_libraries/libMediaPipeTasksCommon_${graph_platform}_graph.a"
  local flags="-ObjC -lc++ -lz -force_load $vision/MediaPipeTasksVision.framework/MediaPipeTasksVision -force_load $graph -framework MediaPipeTasksCommon"
  xcodebuild archive -project "$project" -scheme MediaPipeTasksVision -configuration Release -destination "$destination" -archivePath "$root_dir/.build-artifacts/archives/$archive" ARCHS=arm64 EXCLUDED_ARCHS=x86_64 IPHONEOS_DEPLOYMENT_TARGET=17.0 SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO FRAMEWORK_SEARCH_PATHS="$vision $common" HEADER_SEARCH_PATHS="$vision/MediaPipeTasksVision.framework/Headers $common/MediaPipeTasksCommon.framework/Headers" OTHER_LDFLAGS="$flags"
  local framework="$root_dir/.build-artifacts/archives/$archive.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework"
  mkdir -p "$framework/Headers"
  cp "$root_dir/builder/mediapipe-tasks-vision-wrapper/MediaPipeTasksVision/MediaPipeTasksVision.h" "$framework/Headers/MediaPipeTasksVision.h"
  find "$vision/MediaPipeTasksVision.framework/Headers" -maxdepth 1 -type f -name '*.h' ! -name 'MediaPipeTasksVision.h' -exec cp {} "$framework/Headers/" \;
}
vision_xcframework="$pod_root/MediaPipeTasksVision/frameworks/MediaPipeTasksVision.xcframework"
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
build_one iphoneos 'generic/platform=iOS' MediaPipeTasksVision-iOS ios-arm64
build_one iphonesimulator 'generic/platform=iOS Simulator' MediaPipeTasksVision-Simulator "$simulator_slice"
