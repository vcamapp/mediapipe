#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
required_commands=(bundle xcodebuild plutil file lipo otool nm vtool ditto codesign shasum swift)
for command in "${required_commands[@]}"; do command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }; done
[[ "$(uname -m)" == arm64 ]] || { echo "Apple Silicon Mac is required." >&2; exit 1; }
xcodebuild -version
(cd "$root_dir" && bundle exec pod --version)
swift --version
