#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
tag="${1:-$PACKAGE_VERSION}"

[[ "$tag" == "$PACKAGE_VERSION" ]] || {
  echo "Tag $tag does not match PACKAGE_VERSION $PACKAGE_VERSION" >&2
  exit 1
}

package_url_version=$(grep -oE 'releases/download/[^/]+/MediaPipeTasksVision\.xcframework\.zip' "$root_dir/Package.swift" | cut -d/ -f3)
[[ "$package_url_version" == "$PACKAGE_VERSION" ]] || {
  echo "Package.swift release URL version mismatch: $package_url_version" >&2
  exit 1
}

grep -Fq ".iOS(.v${MINIMUM_IOS_VERSION%%.*})" "$root_dir/Package.swift" || {
  echo "Package.swift iOS platform does not match MINIMUM_IOS_VERSION $MINIMUM_IOS_VERSION" >&2
  exit 1
}
grep -Fq ".macOS(.v${MINIMUM_MACOS_VERSION%%.*})" "$root_dir/Package.swift" || {
  echo "Package.swift macOS platform does not match MINIMUM_MACOS_VERSION $MINIMUM_MACOS_VERSION" >&2
  exit 1
}

for pod in MediaPipeTasksVision MediaPipeTasksCommon; do
  grep -Eq "^  - $pod \($MEDIAPIPE_VERSION\)" "$root_dir/builder/Podfile.lock" || {
    echo "$pod is not locked to $MEDIAPIPE_VERSION" >&2
    exit 1
  }
done

grep -Fq "MediaPipe Tasks Vision $MEDIAPIPE_VERSION" "$root_dir/THIRD_PARTY_NOTICES.md" || {
  echo "THIRD_PARTY_NOTICES.md MediaPipe version mismatch" >&2
  exit 1
}

grep -Fq "OpenCV $OPENCV_VERSION" "$root_dir/THIRD_PARTY_NOTICES.md" || {
  echo "THIRD_PARTY_NOTICES.md OpenCV version mismatch" >&2
  exit 1
}

notes="$root_dir/.build-artifacts/release-notes.md"
metadata="$root_dir/.build-artifacts/metadata/build-metadata.json"
grep -Fq "MediaPipe Tasks Vision: $MEDIAPIPE_VERSION" "$notes" || {
  echo "Release notes MediaPipe version mismatch" >&2
  exit 1
}
grep -Fq "Minimum macOS version: $MINIMUM_MACOS_VERSION" "$notes" || {
  echo "Release notes macOS minimum version mismatch" >&2
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

xcframework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework"
for plist in "$xcframework"/ios-*/MediaPipeTasksVision.framework/Info.plist \
             "$xcframework"/macos-*/MediaPipeTasksVision.framework/Versions/A/Resources/Info.plist; do
  version=$(plutil -extract CFBundleShortVersionString raw -o - "$plist")
  [[ "$version" == "$PACKAGE_VERSION" ]] || {
    echo "Framework version mismatch: $version ($plist)" >&2
    exit 1
  }
done

echo "Version consistency checks passed for package $PACKAGE_VERSION and MediaPipe $MEDIAPIPE_VERSION."
