#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
source "$root_dir/scripts/lib/static-artifacts.sh"

# Every slice links a static library built from upstream MediaPipe plus
# source/patches (one zip per platform). Headers are versioned in-repo under
# source/Headers.
static_root="$root_dir/.build-artifacts/static"
mkdir -p "$static_root"
curl --fail --silent --show-error --location --retry 3 --output "$static_root/LICENSE" \
  "https://raw.githubusercontent.com/google-ai-edge/mediapipe/v$MEDIAPIPE_VERSION/LICENSE"

for platform in "${STATIC_PLATFORMS[@]}"; do
  zip_name=$(static_artifact_name "$platform")
  zip="$static_root/$zip_name"
  if [[ -n "${STATIC_ARTIFACT_DIR:-}" ]]; then
    # Explicitly supplied artifacts (local builds, or ones built earlier in the
    # same CI run) are trusted by provenance and not checked against the pins.
    cp "$STATIC_ARTIFACT_DIR/$zip_name" "$zip"
    echo "Using local $platform artifact ($(shasum -a 256 "$zip" | awk '{print $1}'))"
  else
    [[ -f "$zip" ]] || curl --fail --location --retry 3 --output "$zip" "$STATIC_ARTIFACT_URL/$zip_name" || {
      echo "Pinned $platform artifact is not published at $STATIC_ARTIFACT_URL/$zip_name." >&2
      echo "Run the 'Static libraries' workflow (or source/build-static-lib.sh) and either" >&2
      echo "upload the zips to that release or point STATIC_ARTIFACT_DIR at local copies." >&2
      exit 1
    }
    echo "$(static_artifact_sha256 "$platform")  $zip" | shasum -a 256 -c -
  fi
  rm -rf "${static_root:?}/$platform"
  unzip -oq "$zip" -d "$static_root/$platform"
  library="$static_root/$platform/MediaPipeTasksVision_static.a"
  [[ -f "$library" ]] || { echo "MediaPipeTasksVision_static.a missing in $zip_name" >&2; exit 1; }
  [[ "$(lipo -archs "$library")" == arm64 ]] || { echo "Unexpected $platform artifact architecture" >&2; exit 1; }
done

bundle exec ruby "$root_dir/scripts/generate-wrapper-project.rb"
