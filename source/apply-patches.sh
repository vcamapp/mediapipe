#!/usr/bin/env bash
# Applies the patches that a static build for <platform> needs to an upstream
# MediaPipe checkout. Patches named *-macos-* fix problems of the macOS GPU and
# smoke-test wiring only and are applied to the macOS build alone; every other
# patch applies to all platforms.
set -euo pipefail

usage="usage: $0 <macos|ios|ios-simulator> <mediapipe-src-dir>"
platform="${1:?$usage}"
src_dir="${2:?$usage}"
patch_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"

patches=()
for patch in "$patch_dir"/*.patch; do
  case "$platform" in
    macos) patches+=("$patch") ;;
    ios | ios-simulator) [[ "$(basename "$patch")" == *-macos-* ]] || patches+=("$patch") ;;
    *) echo "$usage" >&2; exit 1 ;;
  esac
done

cd "$src_dir"
git apply --stat "${patches[@]}"
git apply "${patches[@]}"
