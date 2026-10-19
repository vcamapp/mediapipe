#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
source "$root_dir/scripts/lib/static-artifacts.sh"
artifact="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
zip="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework.zip"
[[ -d "$artifact" ]] || { echo "Run make create-xcframework first." >&2; exit 1; }
# Normalize archive metadata so the release ZIP and SwiftPM checksum are reproducible.
find "$artifact" -exec touch -t 200001010000 {} +
rm -f "$zip"
(cd "$root_dir/.build-artifacts" && zip -X -qry "$(basename "$zip")" "$(basename "$artifact")")
checksum=$(swift package compute-checksum "$zip")
sha=$(shasum -a 256 "$zip" | awk '{print $1}')
git_commit=$(git -C "$root_dir" rev-parse HEAD)
# The SHA-256 of each static library zip this package was linked from.
static_shas=()
for platform in "${STATIC_PLATFORMS[@]}"; do
  static_shas+=("$(shasum -a 256 "$root_dir/.build-artifacts/static/$(static_artifact_name "$platform")" | awk '{print $1}')")
done
mkdir -p "$root_dir/.build-artifacts/metadata"
printf '%s\n' "$checksum" > "$root_dir/.build-artifacts/checksums.txt"
printf '%s  %s\n' "$sha" "$(basename "$zip")" >> "$root_dir/.build-artifacts/checksums.txt"
xcode_version=$(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')
printf '{"repository":"vcamapp/mediapipe","packageVersion":"%s","packageBuild":"%s","mediaPipeVersion":"%s","gitCommit":"%s","minimumIOSVersion":"%s","minimumMacOSVersion":"%s","deviceArchitectures":["arm64"],"simulatorArchitectures":["arm64"],"macOSArchitectures":["arm64","x86_64"],"macOSStubArchitectures":["x86_64"],"staticArtifactSHA256":{"macos":"%s","ios":"%s","iosSimulator":"%s"},"xcodeVersion":"%s","artifactSHA256":"%s"}\n' "$PACKAGE_VERSION" "$PACKAGE_BUILD" "$MEDIAPIPE_VERSION" "$git_commit" "$MINIMUM_IOS_VERSION" "$MINIMUM_MACOS_VERSION" "${static_shas[@]}" "$xcode_version" "$sha" > "$root_dir/.build-artifacts/metadata/build-metadata.json"
cat > "$root_dir/.build-artifacts/release-notes.md" <<EOF
### Bundled versions

- Package version: ${PACKAGE_VERSION}
- MediaPipe Tasks Vision: ${MEDIAPIPE_VERSION} (built from source with the patches in source/patches; OpenCV ${OPENCV_VERSION} statically linked)
- Minimum iOS version: ${MINIMUM_IOS_VERSION}
- Minimum macOS version: ${MINIMUM_MACOS_VERSION}
- Device architectures: arm64
- Simulator architectures: arm64
- macOS architectures: arm64 + x86_64 link-only stub (MediaPipe is unavailable on Intel Macs and under Rosetta)
EOF
{
  cat "$root_dir/THIRD_PARTY_NOTICES.md"
  printf '\n\n## Statically linked libraries\n'
  for notice in "$root_dir"/source/licenses/*; do
    printf '\n--- %s ---\n' "$(basename "$notice")"
    cat "$notice"
  done
  printf '\n\n## MediaPipe license\n\n'
  cat "$root_dir/.build-artifacts/static/LICENSE"
} > "$root_dir/.build-artifacts/THIRD_PARTY_NOTICES.txt"
grep -q "Apache License" "$root_dir/.build-artifacts/THIRD_PARTY_NOTICES.txt" || { echo "MediaPipe Apache license notice is missing" >&2; exit 1; }
