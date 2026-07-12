#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
device_archive="$root_dir/.build-artifacts/archives/MediaPipeTasksVision-iOS.xcarchive"
simulator_archive="$root_dir/.build-artifacts/archives/MediaPipeTasksVision-Simulator.xcarchive"
rm -rf "$out"
xcodebuild -create-xcframework \
  -framework "$device_archive/Products/Library/Frameworks/MediaPipeTasksVision.framework" \
  -debug-symbols "$device_archive/dSYMs/MediaPipeTasksVision.framework.dSYM" \
  -framework "$simulator_archive/Products/Library/Frameworks/MediaPipeTasksVision.framework" \
  -debug-symbols "$simulator_archive/dSYMs/MediaPipeTasksVision.framework.dSYM" \
  -output "$out"
