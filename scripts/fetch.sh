#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
export MEDIAPIPE_VERSION

# iOS: Google's official CocoaPods binaries.
mkdir -p "$root_dir/.build-artifacts/pods"
(cd "$root_dir/builder" && bundle exec pod install --deployment --project-directory="$root_dir/builder")

# macOS: prebuilt CPU-only static library, built from upstream MediaPipe plus
# macos/patches. Headers are versioned in-repo under macos/Headers.
macos_dir="$root_dir/.build-artifacts/macos"
macos_zip="$macos_dir/$(basename "$MACOS_ARTIFACT_URL")"
mkdir -p "$macos_dir"
if [[ -n "${MACOS_ARTIFACT_PATH:-}" ]]; then
  # An explicitly supplied artifact (local build, or one built earlier in the
  # same CI run) is trusted by provenance and not checked against the pin.
  cp "$MACOS_ARTIFACT_PATH" "$macos_zip"
  echo "Using local macOS artifact ($(shasum -a 256 "$macos_zip" | awk '{print $1}'))"
elif [[ ! -f "$macos_zip" ]]; then
  curl --fail --location --retry 3 --output "$macos_zip" "$MACOS_ARTIFACT_URL" || {
    echo "Pinned macOS artifact is not published at $MACOS_ARTIFACT_URL." >&2
    echo "Run the 'macOS build dependency' workflow (or macos/build-macos-static-lib.sh) and either" >&2
    echo "upload the zip to that release or point MACOS_ARTIFACT_PATH at a local copy." >&2
    exit 1
  }
fi
if [[ -z "${MACOS_ARTIFACT_PATH:-}" ]]; then
  echo "$MACOS_ARTIFACT_SHA256  $macos_zip" | shasum -a 256 -c -
fi
rm -f "$macos_dir/MediaPipeTasksVision_macos.a"
unzip -oq "$macos_zip" -d "$macos_dir"
[[ -f "$macos_dir/MediaPipeTasksVision_macos.a" ]] || { echo "MediaPipeTasksVision_macos.a missing in artifact zip" >&2; exit 1; }
[[ "$(lipo -archs "$macos_dir/MediaPipeTasksVision_macos.a")" == arm64 ]] || { echo "Unexpected macOS artifact architecture" >&2; exit 1; }

bundle exec ruby "$root_dir/scripts/generate-wrapper-project.rb"
find "$root_dir/builder/Pods" -name '*.xcframework' -print | sort
