#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
latest=$(bundle exec pod trunk info MediaPipeTasksVision | ruby -e '
  versions = STDIN.read.scan(/^\s+- (\d+\.\d+\.\d+) \(/).flatten
  puts versions.map { |v| Gem::Version.new(v) }.max
')
[[ -n "$latest" ]] || { echo "Could not determine latest stable MediaPipeTasksVision version." >&2; exit 1; }
echo "bundled=$MEDIAPIPE_VERSION latest=$latest"
if ruby -r rubygems -e 'exit Gem::Version.new(ARGV[0]) > Gem::Version.new(ARGV[1]) ? 0 : (Gem::Version.new(ARGV[0]) == Gem::Version.new(ARGV[1]) ? 1 : 2)' "$latest" "$MEDIAPIPE_VERSION"; then
  echo "A newer stable CocoaPods release is available: $latest" >&2
  exit 10
fi
comparison=$?
if [[ "$comparison" == 2 ]]; then
  echo "Bundled MediaPipe version $MEDIAPIPE_VERSION is newer than CocoaPods latest $latest; verify the upstream registry." >&2
  exit 11
fi

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
