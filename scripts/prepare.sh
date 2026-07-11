#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root_dir/.build-artifacts/intermediate"
mkdir -p "$out/device" "$out/simulator"
vision=$(find "$root_dir/builder/Pods" -path '*MediaPipeTasksVision.xcframework' -type d -print -quit)
common=$(find "$root_dir/builder/Pods" -path '*MediaPipeTasksCommon.xcframework' -type d -print -quit)
[[ -n "$vision" && -n "$common" ]] || { echo "Required XCFrameworks not found; run make fetch first." >&2; exit 1; }
for platform in device simulator; do
  variant=""; [[ "$platform" == simulator ]] && variant="-simulator"
  for input in "$vision" "$common"; do
    name="$(basename "$input" .xcframework)"
    slice="$input/ios-arm64${variant}"
    if [[ "$platform" == simulator ]]; then slice=$(find "$input" -mindepth 1 -maxdepth 1 -type d -name 'ios-*-simulator' -print -quit); fi
    [[ -d "$slice" ]] || { echo "Missing slice: $slice" >&2; exit 1; }
    destination="$out/$platform/$name"
    ditto "$slice" "$destination"
    binary=$(find "$destination" -type f -path '*/MediaPipeTasksVision.framework/MediaPipeTasksVision' -o -type f -path '*/MediaPipeTasksCommon.framework/MediaPipeTasksCommon' | head -1)
    if [[ "$platform" == simulator && -n "$binary" ]] && lipo -archs "$binary" 2>/dev/null | grep -q x86_64; then
      tmp="${binary}.arm64"
      lipo "$binary" -thin arm64 -output "$tmp"
      mv "$tmp" "$binary"
    fi
  done
done
