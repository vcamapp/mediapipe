#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
rm -rf "$out"
xcodebuild -create-xcframework -framework "$root_dir/.build-artifacts/archives/MediaPipeTasksVision-iOS.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework" -framework "$root_dir/.build-artifacts/archives/MediaPipeTasksVision-Simulator.xcarchive/Products/Library/Frameworks/MediaPipeTasksVision.framework" -output "$out"
