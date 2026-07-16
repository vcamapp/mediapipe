#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
framework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework/ios-arm64-simulator"
macos_framework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework/macos-arm64"
[[ -d "$framework" && -d "$macos_framework" ]] || { echo "Build the XCFramework first." >&2; exit 1; }
"$root_dir/scripts/prepare-smoke-test.sh"
bundle exec ruby "$root_dir/scripts/generate-smoke-test-project.rb"
xcrun --sdk iphonesimulator swiftc -target "arm64-apple-ios${MINIMUM_IOS_VERSION}-simulator" -F "$framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"
xcrun --sdk macosx swiftc -target "arm64-apple-macos${MINIMUM_MACOS_VERSION}" -F "$macos_framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"

# macOS (native run)
xcodebuild test -project "$root_dir/smoke-test/MediaPipeSmokeTest.xcodeproj" -scheme MediaPipeSmokeTestsMac -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO

# iOS Simulator
simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone 15 Pro (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone.* (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || { echo "No available iOS Simulator found." >&2; exit 1; }
xcodebuild test -project "$root_dir/smoke-test/MediaPipeSmokeTest.xcodeproj" -scheme MediaPipeSmokeTests -destination "platform=iOS Simulator,id=$simulator_id" CODE_SIGNING_ALLOWED=NO
