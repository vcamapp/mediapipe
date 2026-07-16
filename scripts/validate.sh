#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
binary="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
[[ -f "$binary/Info.plist" ]] || { echo "XCFramework not found" >&2; exit 1; }
[[ -d "$binary/ios-arm64" && -d "$binary/ios-arm64-simulator" && -d "$binary/macos-arm64" ]] || { echo "Required slices are missing" >&2; exit 1; }
slice_count=$(find "$binary" -mindepth 1 -maxdepth 1 -type d \( -name 'ios-*' -o -name 'macos-*' \) | wc -l | tr -d ' ')
[[ "$slice_count" == 3 ]] || { echo "Unexpected XCFramework slice count: $slice_count" >&2; exit 1; }

check_common() {
  local framework="$1" plist="$2"
  file "$framework/MediaPipeTasksVision" | grep -q 'dynamically linked' || { echo "Not dynamic: $framework" >&2; exit 1; }
  [[ "$(lipo -archs "$framework/MediaPipeTasksVision")" == arm64 ]] || { echo "Unexpected architecture: $framework" >&2; exit 1; }
  plutil -extract CFBundlePackageType raw -o - "$plist" | grep -q '^FMWK$' || { echo "Invalid framework package type" >&2; exit 1; }
  plutil -extract CFBundleExecutable raw -o - "$plist" | grep -q '^MediaPipeTasksVision$' || { echo "Invalid executable name" >&2; exit 1; }
  plutil -extract CFBundleIdentifier raw -o - "$plist" | grep -q '^com.vcamapp.mediapipe.tasks.vision$' || { echo "Invalid bundle identifier" >&2; exit 1; }
  plutil -extract CFBundleShortVersionString raw -o - "$plist" | grep -q "^${PACKAGE_VERSION//./\\.}$" || { echo "Invalid framework version" >&2; exit 1; }
  plutil -extract CFBundleVersion raw -o - "$plist" | grep -q "^${PACKAGE_BUILD}$" || { echo "Invalid framework build" >&2; exit 1; }
  local dependencies
  # tail -n +2 drops otool's header line (the file's own path), which would
  # self-match when the repository checkout lives under a path like /tmp/.
  dependencies=$(otool -L "$framework/MediaPipeTasksVision" | tail -n +2)
  ! grep -Eiq 'builder/Pods|Bazel|DerivedData|/tmp/|/Users/.*/workspace' <<< "$dependencies" || { echo "Build-path dependency found: $framework" >&2; exit 1; }
}

check_symbols() {
  local binary_file="$1"
  local symbols
  symbols=$(nm -gU "$binary_file")
  for symbol in $REQUIRED_OBJC_CLASSES; do
    grep -Fq "$symbol" <<< "$symbols" || { echo "Missing public symbol: $symbol ($binary_file)" >&2; exit 1; }
  done
}

check_dsym() {
  local slice="$1" binary_file="$2"
  local dsym="$binary/$slice/dSYMs/MediaPipeTasksVision.framework.dSYM"
  [[ -d "$dsym" ]] || { echo "Missing dSYM: $slice" >&2; exit 1; }
  local binary_uuid dsym_uuid
  binary_uuid=$(dwarfdump --uuid "$binary_file" | awk 'NR == 1 {print $2}')
  dsym_uuid=$(dwarfdump --uuid "$dsym" | awk 'NR == 1 {print $2}')
  [[ -n "$binary_uuid" && "$binary_uuid" == "$dsym_uuid" ]] || { echo "dSYM UUID mismatch: $slice" >&2; exit 1; }
}

# --- iOS slices (shallow framework bundles) ----------------------------------
for slice in ios-arm64 ios-arm64-simulator; do
  framework="$binary/$slice/MediaPipeTasksVision.framework"
  [[ -f "$framework/Info.plist" && -d "$framework/Headers" && -f "$framework/Modules/module.modulemap" ]] || { echo "Incomplete framework bundle: $framework" >&2; exit 1; }
  check_common "$framework" "$framework/Info.plist"
  plutil -extract MinimumOSVersion raw -o - "$framework/Info.plist" | grep -q "^${MINIMUM_IOS_VERSION//./\\.}$" || { echo "Invalid minimum OS: $slice" >&2; exit 1; }
  install_name=$(otool -D "$framework/MediaPipeTasksVision" | tail -1)
  [[ "$install_name" == '@rpath/MediaPipeTasksVision.framework/MediaPipeTasksVision' ]] || { echo "Invalid install name: $install_name" >&2; exit 1; }
  check_dsym "$slice" "$framework/MediaPipeTasksVision"
done
check_symbols "$binary/ios-arm64/MediaPipeTasksVision.framework/MediaPipeTasksVision"

# --- macOS slice (versioned framework bundle: Versions/A) ---------------------
framework="$binary/macos-arm64/MediaPipeTasksVision.framework"
versioned="$framework/Versions/A"
[[ -d "$versioned" ]] || { echo "macOS framework is not a versioned bundle: $framework" >&2; exit 1; }
[[ -f "$versioned/Resources/Info.plist" && -d "$versioned/Headers" && -f "$versioned/Modules/module.modulemap" ]] || { echo "Incomplete framework bundle: $framework" >&2; exit 1; }
[[ -L "$framework/MediaPipeTasksVision" && -L "$framework/Headers" ]] || { echo "macOS framework top-level symlinks are missing" >&2; exit 1; }
check_common "$framework" "$versioned/Resources/Info.plist"
plutil -extract LSMinimumSystemVersion raw -o - "$versioned/Resources/Info.plist" | grep -q "^${MINIMUM_MACOS_VERSION//./\\.}$" || { echo "Invalid minimum macOS version" >&2; exit 1; }
install_name=$(otool -D "$framework/MediaPipeTasksVision" | tail -1)
[[ "$install_name" == '@rpath/MediaPipeTasksVision.framework/Versions/A/MediaPipeTasksVision' ]] || { echo "Invalid install name: $install_name" >&2; exit 1; }
check_dsym macos-arm64 "$framework/MediaPipeTasksVision"
check_symbols "$framework/MediaPipeTasksVision"
# OpenCV must be statically linked; an external dylib dependency would force
# consumers to install Homebrew opencv@4.
opencv_deps=$(otool -L "$framework/MediaPipeTasksVision" | grep -i opencv || true)
if [[ -n "$opencv_deps" ]]; then
  echo "macOS slice must not depend on external OpenCV dylibs:" >&2
  echo "$opencv_deps" >&2
  exit 1
fi
