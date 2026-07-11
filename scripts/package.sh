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
mkdir -p "$root_dir/.build-artifacts/metadata"
printf '%s\n' "$checksum" > "$root_dir/.build-artifacts/checksums.txt"
printf '%s  %s\n' "$sha" "$(basename "$zip")" >> "$root_dir/.build-artifacts/checksums.txt"
xcode_version=$(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')
cocoapods_version=$(bundle exec pod --version)
printf '{"repository":"vcamapp/mediapipe","packageVersion":"%s","packageBuild":"%s","mediaPipeVersion":"%s","minimumIOSVersion":"%s","deviceArchitectures":["arm64"],"simulatorArchitectures":["arm64"],"xcodeVersion":"%s","cocoaPodsVersion":"%s","artifactSHA256":"%s","swiftPackageChecksum":"%s"}\n' "$PACKAGE_VERSION" "$PACKAGE_BUILD" "$MEDIAPIPE_VERSION" "$MINIMUM_IOS_VERSION" "$xcode_version" "$cocoapods_version" "$sha" "$checksum" > "$root_dir/.build-artifacts/metadata/build-metadata.json"
{
  cat "$root_dir/THIRD_PARTY_NOTICES.md"
  printf '\n\n## CocoaPods licenses\n'
  find "$root_dir/builder/Pods" -type f \( -iname 'LICENSE' -o -iname 'LICENSE.txt' -o -iname 'NOTICE' -o -iname 'NOTICE.txt' \) -print0 | while IFS= read -r -d '' notice; do
    printf '\n--- %s ---\n' "${notice#$root_dir/builder/Pods/}"
    cat "$notice"
  done
} > "$root_dir/.build-artifacts/THIRD_PARTY_NOTICES.txt"
dsym_stage="$root_dir/.build-artifacts/dSYMs"
rm -rf "$dsym_stage"
mkdir -p "$dsym_stage"
ditto "$root_dir/.build-artifacts/archives/MediaPipeTasksVision-iOS.xcarchive/dSYMs" "$dsym_stage/MediaPipeTasksVision-iOS.dSYMs"
ditto "$root_dir/.build-artifacts/archives/MediaPipeTasksVision-Simulator.xcarchive/dSYMs" "$dsym_stage/MediaPipeTasksVision-Simulator.dSYMs"
find "$dsym_stage" -exec touch -t 200001010000 {} +
(cd "$root_dir/.build-artifacts" && zip -X -qry MediaPipeTasksVision.dSYMs.zip dSYMs)
