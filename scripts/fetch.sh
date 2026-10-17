#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"

# iOS: Google's official binaries, as declared by the binary targets of
# upstream's Package.swift at the pinned tag. The manifest's checksums verify
# the downloads.
ios_dir="$root_dir/.build-artifacts/ios"
upstream_raw="https://raw.githubusercontent.com/google-ai-edge/mediapipe/v$MEDIAPIPE_VERSION"
mkdir -p "$ios_dir"
curl --fail --silent --show-error --location --retry 3 --output "$ios_dir/Package.swift" "$upstream_raw/Package.swift"
curl --fail --silent --show-error --location --retry 3 --output "$ios_dir/LICENSE" "$upstream_raw/LICENSE"
rm -rf "$ios_dir"/*.xcframework
for target in MediaPipeTasksVision MediaPipeTasksCommonBinary MediaPipeTaskGraphsBinary; do
  entry=$(ruby -e '
    name = Regexp.escape(ARGV[1])
    match = File.read(ARGV[0]).match(/\.binaryTarget\(\s*name:\s*"#{name}",\s*url:\s*"([^"]+)",\s*checksum:\s*"(\h{64})"\s*\)/)
    abort "Binary target #{ARGV[1]} not found in #{ARGV[0]}" unless match
    puts match.captures.join(" ")
  ' "$ios_dir/Package.swift" "$target")
  read -r url checksum <<< "$entry"
  zip="$ios_dir/$(basename "$url")"
  [[ -f "$zip" ]] || curl --fail --location --retry 3 --output "$zip" "$url"
  echo "$checksum  $zip" | shasum -a 256 -c -
  unzip -oq "$zip" -d "$ios_dir"
done
for xcframework in MediaPipeTasksVision MediaPipeTasksCommon MediaPipeTaskGraphs_library; do
  [[ -f "$ios_dir/$xcframework.xcframework/Info.plist" ]] || { echo "$xcframework.xcframework missing in the upstream binaries" >&2; exit 1; }
done

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
find "$ios_dir" -maxdepth 1 -name '*.xcframework' -print | sort
