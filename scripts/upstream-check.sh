#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
# Upstream stopped publishing every release to CocoaPods (1.1.0 shipped only
# as SwiftPM binaries), so the GitHub release is the source of truth.
auth_header=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then auth_header=(--header "Authorization: Bearer $GITHUB_TOKEN"); fi
latest=$(curl --fail --silent --show-error --location --retry 3 ${auth_header[@]+"${auth_header[@]}"} \
  https://api.github.com/repos/google-ai-edge/mediapipe/releases/latest \
  | ruby -r json -e 'puts JSON.parse(STDIN.read).fetch("tag_name").delete_prefix("v")')
[[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Could not determine the latest upstream MediaPipe release (got '$latest')." >&2; exit 1; }
echo "bundled=$MEDIAPIPE_VERSION latest=$latest"
comparison=$(ruby -r rubygems -e 'puts Gem::Version.new(ARGV[0]) <=> Gem::Version.new(ARGV[1])' "$latest" "$MEDIAPIPE_VERSION")
case "$comparison" in
  1)
    echo "A newer upstream MediaPipe release is available: $latest" >&2
    if ! pods=$(bundle exec pod trunk info MediaPipeTasksVision); then
      echo "Could not check whether MediaPipeTasksVision $latest is on CocoaPods." >&2
    elif ! grep -Fq -- "- $latest (" <<< "$pods"; then
      echo "MediaPipeTasksVision $latest is not on CocoaPods; the iOS slice has to come from upstream's SwiftPM binaries." >&2
    fi
    exit 10
    ;;
  -1)
    echo "Bundled MediaPipe version $MEDIAPIPE_VERSION is newer than the latest upstream release $latest; verify the upstream releases." >&2
    exit 11
    ;;
esac

# Verify the macOS patches in macos/patches still apply cleanly to the pinned
# upstream tag. Catches drift when MEDIAPIPE_VERSION is bumped without
# rebasing the patches. Uses a sparse blobless clone so only the touched
# paths are downloaded, and any fetch failure is loud instead of surfacing
# as a bogus "patch does not apply".
patch_dir="$root_dir/macos/patches"
[[ -d "$patch_dir" ]] || { echo "macos/patches is missing" >&2; exit 1; }
tmp_tree=$(mktemp -d)
trap 'rm -rf "$tmp_tree"' EXIT
git clone --quiet --depth 1 --branch "v$MEDIAPIPE_VERSION" --filter=blob:none --sparse \
  https://github.com/google-ai-edge/mediapipe.git "$tmp_tree"
patch_dirs=()
while IFS= read -r dir; do patch_dirs+=("$dir"); done < <(
  cat "$patch_dir"/*.patch | sed -n 's|^--- a/||p; s|^+++ b/||p' \
    | grep -v '^/dev/null' | xargs -n1 dirname | sort -u
)
(cd "$tmp_tree" && git sparse-checkout set "${patch_dirs[@]}")
for patch in "$patch_dir"/*.patch; do
  if ! (cd "$tmp_tree" && git apply --check "$patch"); then
    echo "macOS patch no longer applies to upstream v$MEDIAPIPE_VERSION: $(basename "$patch")" >&2
    exit 12
  fi
done
echo "macOS patches apply cleanly to upstream v$MEDIAPIPE_VERSION"
