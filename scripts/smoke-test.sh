#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
framework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework/ios-arm64-simulator"
[[ -d "$framework" ]] || { echo "Build the XCFramework first." >&2; exit 1; }
"$root_dir/scripts/prepare-smoke-test.sh"
bundle exec ruby "$root_dir/scripts/generate-smoke-test-project.rb"
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios17.0-simulator -F "$framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"
simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone 15 Pro (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone.* (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || { echo "No available iOS Simulator found." >&2; exit 1; }
xcodebuild test -project "$root_dir/smoke-test/MediaPipeSmokeTest.xcodeproj" -scheme MediaPipeSmokeTests -destination "platform=iOS Simulator,id=$simulator_id" CODE_SIGNING_ALLOWED=NO
