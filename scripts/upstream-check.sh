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
if [[ "$latest" != "$MEDIAPIPE_VERSION" ]]; then
  echo "A newer stable CocoaPods release is available: $latest" >&2
  exit 10
fi
