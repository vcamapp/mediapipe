#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
[[ -f "$binary/Info.plist" ]] || { echo "XCFramework not found" >&2; exit 1; }
for framework in "$binary"/ios-*/MediaPipeTasksVision.framework; do
  file "$framework/MediaPipeTasksVision" | grep -q 'dynamically linked' || { echo "Not dynamic: $framework" >&2; exit 1; }
  [[ "$(lipo -archs "$framework/MediaPipeTasksVision")" == arm64 ]] || { echo "Unexpected architecture" >&2; exit 1; }
  [[ -f "$framework/Info.plist" && -d "$framework/Headers" && -f "$framework/Modules/module.modulemap" ]] || { echo "Incomplete framework bundle: $framework" >&2; exit 1; }
  plutil -extract CFBundlePackageType raw -o - "$framework/Info.plist" | grep -q '^FMWK$' || { echo "Invalid framework package type" >&2; exit 1; }
  plutil -extract MinimumOSVersion raw -o - "$framework/Info.plist" | grep -q '^17.0$' || { echo "Invalid minimum OS" >&2; exit 1; }
  install_name=$(otool -D "$framework/MediaPipeTasksVision" | tail -1)
  [[ "$install_name" == '@rpath/MediaPipeTasksVision.framework/MediaPipeTasksVision' ]] || { echo "Invalid install name: $install_name" >&2; exit 1; }
  dependencies=$(otool -L "$framework/MediaPipeTasksVision")
  ! grep -Eiq 'builder/Pods|Bazel|DerivedData|/tmp/|/Users/.*/workspace' <<< "$dependencies" || { echo "Build-path dependency found: $framework" >&2; exit 1; }
done
device_binary="$binary/ios-arm64/MediaPipeTasksVision.framework/MediaPipeTasksVision"
symbols=$(nm -gU "$device_binary")
for symbol in MPPFaceLandmarker MPPGestureRecognizer MPPHandLandmarker MPPHolisticLandmarker MPPPoseLandmarker; do
  grep -Fq "$symbol" <<< "$symbols" || { echo "Missing public symbol: $symbol" >&2; exit 1; }
done
