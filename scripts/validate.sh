#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
binary="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
[[ -f "$binary/Info.plist" ]] || { echo "XCFramework not found" >&2; exit 1; }
[[ -d "$binary/ios-arm64" && -d "$binary/ios-arm64-simulator" ]] || { echo "Required slices are missing" >&2; exit 1; }
slice_count=$(find "$binary" -mindepth 1 -maxdepth 1 -type d -name 'ios-*' | wc -l | tr -d ' ')
[[ "$slice_count" == 2 ]] || { echo "Unexpected XCFramework slice count: $slice_count" >&2; exit 1; }
for framework in "$binary"/ios-*/MediaPipeTasksVision.framework; do
  file "$framework/MediaPipeTasksVision" | grep -q 'dynamically linked' || { echo "Not dynamic: $framework" >&2; exit 1; }
  [[ "$(lipo -archs "$framework/MediaPipeTasksVision")" == arm64 ]] || { echo "Unexpected architecture" >&2; exit 1; }
  [[ -f "$framework/Info.plist" && -d "$framework/Headers" && -f "$framework/Modules/module.modulemap" ]] || { echo "Incomplete framework bundle: $framework" >&2; exit 1; }
  plutil -extract CFBundlePackageType raw -o - "$framework/Info.plist" | grep -q '^FMWK$' || { echo "Invalid framework package type" >&2; exit 1; }
  plutil -extract MinimumOSVersion raw -o - "$framework/Info.plist" | grep -q '^17.0$' || { echo "Invalid minimum OS" >&2; exit 1; }
  plutil -extract CFBundleExecutable raw -o - "$framework/Info.plist" | grep -q '^MediaPipeTasksVision$' || { echo "Invalid executable name" >&2; exit 1; }
  plutil -extract CFBundleIdentifier raw -o - "$framework/Info.plist" | grep -q '^com.vcamapp.mediapipe.tasks.vision$' || { echo "Invalid bundle identifier" >&2; exit 1; }
  plutil -extract CFBundleShortVersionString raw -o - "$framework/Info.plist" | grep -q "^${PACKAGE_VERSION//./\\.}$" || { echo "Invalid framework version" >&2; exit 1; }
  plutil -extract CFBundleVersion raw -o - "$framework/Info.plist" | grep -q "^${PACKAGE_BUILD}$" || { echo "Invalid framework build" >&2; exit 1; }
  install_name=$(otool -D "$framework/MediaPipeTasksVision" | tail -1)
  [[ "$install_name" == '@rpath/MediaPipeTasksVision.framework/MediaPipeTasksVision' ]] || { echo "Invalid install name: $install_name" >&2; exit 1; }
  dependencies=$(otool -L "$framework/MediaPipeTasksVision")
  ! grep -Eiq 'builder/Pods|Bazel|DerivedData|/tmp/|/Users/.*/workspace' <<< "$dependencies" || { echo "Build-path dependency found: $framework" >&2; exit 1; }
done
for slice in ios-arm64 ios-arm64-simulator; do
  binary_file="$binary/$slice/MediaPipeTasksVision.framework/MediaPipeTasksVision"
  dsym="$binary/$slice/dSYMs/MediaPipeTasksVision.framework.dSYM"
  [[ -d "$dsym" ]] || { echo "Missing dSYM: $slice" >&2; exit 1; }
  binary_uuid=$(dwarfdump --uuid "$binary_file" | awk 'NR == 1 {print $2}')
  dsym_uuid=$(dwarfdump --uuid "$dsym" | awk 'NR == 1 {print $2}')
  [[ -n "$binary_uuid" && "$binary_uuid" == "$dsym_uuid" ]] || { echo "dSYM UUID mismatch: $slice" >&2; exit 1; }
done
device_binary="$binary/ios-arm64/MediaPipeTasksVision.framework/MediaPipeTasksVision"
symbols=$(nm -gU "$device_binary")
for symbol in MPPFaceLandmarker MPPGestureRecognizer MPPHandLandmarker MPPHolisticLandmarker MPPPoseLandmarker; do
  grep -Fq "$symbol" <<< "$symbols" || { echo "Missing public symbol: $symbol" >&2; exit 1; }
done
