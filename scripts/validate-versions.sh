#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
tag="${1:-${GITHUB_REF_NAME:-$PACKAGE_VERSION}}"

[[ "$tag" == "$PACKAGE_VERSION" ]] || {
  echo "Tag $tag does not match PACKAGE_VERSION $PACKAGE_VERSION" >&2
  exit 1
}

package_url_version=$(grep -oE 'releases/download/[^/]+/MediaPipeTasksVision\.xcframework\.zip' "$root_dir/Package.swift" | cut -d/ -f3)
[[ "$package_url_version" == "$PACKAGE_VERSION" ]] || {
  echo "Package.swift release URL version mismatch: $package_url_version" >&2
  exit 1
}

for pod in MediaPipeTasksVision MediaPipeTasksCommon; do
  grep -Eq "^  - $pod \($MEDIAPIPE_VERSION\)" "$root_dir/builder/Podfile.lock" || {
    echo "$pod is not locked to $MEDIAPIPE_VERSION" >&2
    exit 1
  }
done

grep -Fq "MediaPipe Tasks Vision $MEDIAPIPE_VERSION" "$root_dir/README.md" || {
  echo "README MediaPipe version mismatch" >&2
  exit 1
}
grep -Fq "MediaPipe Tasks Vision $MEDIAPIPE_VERSION" "$root_dir/THIRD_PARTY_NOTICES.md" || {
  echo "THIRD_PARTY_NOTICES.md MediaPipe version mismatch" >&2
  exit 1
}

notes="$root_dir/.build-artifacts/release-notes.md"
metadata="$root_dir/.build-artifacts/metadata/build-metadata.json"
grep -Fq "MediaPipe Tasks Vision: $MEDIAPIPE_VERSION" "$notes" || {
  echo "Release notes MediaPipe version mismatch" >&2
  exit 1
}
grep -Fq "\"packageVersion\":\"$PACKAGE_VERSION\"" "$metadata" || {
  echo "Build metadata package version mismatch" >&2
  exit 1
}
grep -Fq "\"mediaPipeVersion\":\"$MEDIAPIPE_VERSION\"" "$metadata" || {
  echo "Build metadata MediaPipe version mismatch" >&2
  exit 1
}

for framework in "$root_dir"/.build-artifacts/MediaPipeTasksVision.xcframework/ios-*/MediaPipeTasksVision.framework; do
  version=$(
    plutil -extract CFBundleShortVersionString raw -o - "$framework/Info.plist"
  )
  [[ "$version" == "$PACKAGE_VERSION" ]] || {
    echo "Framework version mismatch: $version" >&2
    exit 1
  }
done

echo "Version consistency checks passed for package $PACKAGE_VERSION and MediaPipe $MEDIAPIPE_VERSION."
