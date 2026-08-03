#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
device_archive="$root_dir/.build-artifacts/archives/MediaPipeTasksVision-iOS.xcarchive"
simulator_archive="$root_dir/.build-artifacts/archives/MediaPipeTasksVision-Simulator.xcarchive"
macos_archive="$root_dir/.build-artifacts/archives/MediaPipeTasksVision-macOS.xcarchive"
stub_dir="$root_dir/.build-artifacts/macos-stub"
staging="$root_dir/.build-artifacts/macos-universal"

# The macOS framework ships universal: the arm64 slice carries the real
# MediaPipe implementation, the x86_64 slice is the link-only stub that lets
# universal apps link and launch (builder/x86_64-stub).
[[ -f "$stub_dir/MediaPipeTasksVision" ]] || { echo "x86_64 stub not built; run scripts/build-x86_64-stub.sh first." >&2; exit 1; }
rm -rf "$staging"
mkdir -p "$staging"
cp -R "$macos_archive/Products/Library/Frameworks/MediaPipeTasksVision.framework" "$staging/"
cp -R "$macos_archive/dSYMs/MediaPipeTasksVision.framework.dSYM" "$staging/"
macos_framework="$staging/MediaPipeTasksVision.framework"
macos_dsym="$staging/MediaPipeTasksVision.framework.dSYM"
lipo -create "$macos_framework/Versions/A/MediaPipeTasksVision" "$stub_dir/MediaPipeTasksVision" \
  -output "$staging/binary" && mv "$staging/binary" "$macos_framework/Versions/A/MediaPipeTasksVision"
lipo -create "$macos_dsym/Contents/Resources/DWARF/MediaPipeTasksVision" "$stub_dir/MediaPipeTasksVision.dSYM/Contents/Resources/DWARF/MediaPipeTasksVision" \
  -output "$staging/dwarf" && mv "$staging/dwarf" "$macos_dsym/Contents/Resources/DWARF/MediaPipeTasksVision"

rm -rf "$out"
xcodebuild -create-xcframework \
  -framework "$device_archive/Products/Library/Frameworks/MediaPipeTasksVision.framework" \
  -debug-symbols "$device_archive/dSYMs/MediaPipeTasksVision.framework.dSYM" \
  -framework "$simulator_archive/Products/Library/Frameworks/MediaPipeTasksVision.framework" \
  -debug-symbols "$simulator_archive/dSYMs/MediaPipeTasksVision.framework.dSYM" \
  -framework "$macos_framework" \
  -debug-symbols "$macos_dsym" \
  -output "$out"
