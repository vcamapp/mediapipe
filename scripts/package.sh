#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
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
podfile_lock_sha=$(shasum -a 256 "$root_dir/builder/Podfile.lock" | awk '{print $1}')
mkdir -p "$root_dir/.build-artifacts/metadata"
printf '%s\n' "$checksum" > "$root_dir/.build-artifacts/checksums.txt"
printf '%s  %s\n' "$sha" "$(basename "$zip")" >> "$root_dir/.build-artifacts/checksums.txt"
xcode_version=$(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')
cocoapods_version=$(bundle exec pod --version)
printf '{"repository":"vcamapp/mediapipe","packageVersion":"%s","packageBuild":"%s","mediaPipeVersion":"%s","gitCommit":"%s","podfileLockSHA256":"%s","minimumIOSVersion":"%s","deviceArchitectures":["arm64"],"simulatorArchitectures":["arm64"],"xcodeVersion":"%s","cocoaPodsVersion":"%s","artifactSHA256":"%s"}\n' "$PACKAGE_VERSION" "$PACKAGE_BUILD" "$MEDIAPIPE_VERSION" "$git_commit" "$podfile_lock_sha" "$MINIMUM_IOS_VERSION" "$xcode_version" "$cocoapods_version" "$sha" > "$root_dir/.build-artifacts/metadata/build-metadata.json"
cat > "$root_dir/.build-artifacts/release-notes.md" <<EOF
## MediaPipe Tasks Vision ${PACKAGE_VERSION}

Swift Package Manager distribution of MediaPipe Tasks Vision.

### Bundled versions

- Package version: ${PACKAGE_VERSION}
- MediaPipe Tasks Vision: ${MEDIAPIPE_VERSION}
- Minimum iOS version: ${MINIMUM_IOS_VERSION}
- Device architectures: arm64
- Simulator architectures: arm64

### Installation

Swift code:
import MediaPipeTasksVision

### Artifact

- MediaPipeTasksVision.xcframework.zip
- SHA-256: ${sha}
EOF
{
  cat "$root_dir/THIRD_PARTY_NOTICES.md"
  printf '\n\n## CocoaPods licenses\n'
  find "$root_dir/builder/Pods" -type f \( -iname 'LICENSE' -o -iname 'LICENSE.txt' -o -iname 'LICENSE.md' -o -iname 'NOTICE' -o -iname 'NOTICE.txt' -o -iname 'NOTICE.md' -o -iname 'COPYING' -o -iname 'COPYING.txt' -o -iname 'PATENTS' -o -iname 'PATENTS.txt' \) -print0 | while IFS= read -r -d '' notice; do
    printf '\n--- %s ---\n' "${notice#$root_dir/builder/Pods/}"
    cat "$notice"
  done
} > "$root_dir/.build-artifacts/THIRD_PARTY_NOTICES.txt"
grep -q "Apache License" "$root_dir/.build-artifacts/THIRD_PARTY_NOTICES.txt" || { echo "MediaPipe Apache license notice is missing" >&2; exit 1; }
