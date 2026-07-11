#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
export MEDIAPIPE_VERSION
mkdir -p "$root_dir/.build-artifacts/pods"
(cd "$root_dir/builder" && bundle exec pod install --deployment --project-directory="$root_dir/builder")
bundle exec ruby "$root_dir/scripts/generate-wrapper-project.rb"
find "$root_dir/builder/Pods" -name '*.xcframework' -print | sort
