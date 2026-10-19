#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
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
    exit 10
    ;;
  -1)
    echo "Bundled MediaPipe version $MEDIAPIPE_VERSION is newer than the latest upstream release $latest; verify the upstream releases." >&2
    exit 11
    ;;
esac

# Verify the patches in source/patches still apply to the pinned upstream tag
# for every platform. Catches drift when MEDIAPIPE_VERSION is bumped without
# rebasing the patches. Later patches edit files earlier ones changed, and
# git apply --check judges every patch against the untouched tree, so each
# platform's set is really applied as the build does and the tree is reset.
# Uses a sparse blobless clone so only the touched paths are downloaded, and
# any fetch failure is loud instead of surfacing as a bogus "patch does not
# apply". Root-level files are always in a cone-mode sparse checkout, and "."
# as a pattern would turn cone mode off.
patch_dir="$root_dir/source/patches"
[[ -d "$patch_dir" ]] || { echo "source/patches is missing" >&2; exit 1; }
tmp_tree=$(mktemp -d)
trap 'rm -rf "$tmp_tree"' EXIT
git clone --quiet --depth 1 --branch "v$MEDIAPIPE_VERSION" --filter=blob:none --sparse \
  https://github.com/google-ai-edge/mediapipe.git "$tmp_tree"
patch_dirs=()
while IFS= read -r dir; do patch_dirs+=("$dir"); done < <(
  cat "$patch_dir"/*.patch | sed -n 's|^--- a/||p; s|^+++ b/||p' \
    | grep -v '^/dev/null' | xargs -n1 dirname | grep -vx '\.' | sort -u
)
git -C "$tmp_tree" sparse-checkout set "${patch_dirs[@]}"
for platform in macos ios; do
  if ! "$root_dir/source/apply-patches.sh" "$platform" "$tmp_tree" >/dev/null; then
    echo "The $platform patches no longer apply to upstream v$MEDIAPIPE_VERSION" >&2
    exit 12
  fi
  git -C "$tmp_tree" checkout --quiet -- .
  git -C "$tmp_tree" clean --quiet --force -d
done
echo "Patches apply cleanly to upstream v$MEDIAPIPE_VERSION"
