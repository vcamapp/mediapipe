#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then export PATH="/opt/homebrew/opt/ruby/bin:$PATH"; fi
source "$root_dir/config/versions.env"
framework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework/ios-arm64-simulator"
macos_framework="$root_dir/.build-artifacts/MediaPipeTasksVision.xcframework/macos-arm64_x86_64"
[[ -d "$framework" && -d "$macos_framework" ]] || { echo "Build the XCFramework first." >&2; exit 1; }
"$root_dir/scripts/prepare-smoke-test.sh"
bundle exec ruby "$root_dir/scripts/generate-smoke-test-project.rb"
xcrun --sdk iphonesimulator swiftc -target "arm64-apple-ios${MINIMUM_IOS_VERSION}-simulator" -F "$framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"
xcrun --sdk macosx swiftc -target "arm64-apple-macos${MINIMUM_MACOS_VERSION}" -F "$macos_framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"
xcrun --sdk macosx swiftc -target "x86_64-apple-macos${MINIMUM_MACOS_VERSION}" -F "$macos_framework" -framework MediaPipeTasksVision -typecheck "$root_dir/smoke-test/Smoke.swift"

# x86_64 stub: the executable must link against the stub slice, and (when
# Rosetta is available) load and run without MediaPipe.
stub_smoke="$root_dir/.build-artifacts/stub-smoke"
xcrun --sdk macosx swiftc -target "x86_64-apple-macos${MINIMUM_MACOS_VERSION}" \
  -F "$macos_framework" -framework MediaPipeTasksVision \
  -Xlinker -rpath -Xlinker "$macos_framework" \
  -o "$stub_smoke" "$root_dir/smoke-test/StubSmoke.swift"
if arch -x86_64 /usr/bin/true 2>/dev/null; then
  arch -x86_64 "$stub_smoke"
else
  echo "Rosetta is unavailable; skipped running the x86_64 stub smoke test."
fi

# Package-level validation against the just-built XCFramework: the Swift
# target must build for both macOS architectures, and the unit tests exercise
# the availability/factory API natively.
export MEDIAPIPE_XCFRAMEWORK_PATH=".build-artifacts/MediaPipeTasksVision.xcframework"
for triple in "arm64-apple-macosx${MINIMUM_MACOS_VERSION}" "x86_64-apple-macosx${MINIMUM_MACOS_VERSION}"; do
  swift build --package-path "$root_dir" --triple "$triple" \
    --scratch-path "$root_dir/.build-artifacts/spm-validation" --manifest-cache none
done
swift test --package-path "$root_dir" \
  --scratch-path "$root_dir/.build-artifacts/spm-validation" --manifest-cache none
unset MEDIAPIPE_XCFRAMEWORK_PATH

# macOS (native run)
xcodebuild test -project "$root_dir/smoke-test/MediaPipeSmokeTest.xcodeproj" -scheme MediaPipeSmokeTestsMac -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO

# iOS Simulator
simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone 15 Pro (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || simulator_id=$(xcrun simctl list devices available | sed -n 's/.*iPhone.* (\([A-F0-9-]*\)).*/\1/p' | head -1)
[[ -n "$simulator_id" ]] || { echo "No available iOS Simulator found." >&2; exit 1; }
xcodebuild test -project "$root_dir/smoke-test/MediaPipeSmokeTest.xcodeproj" -scheme MediaPipeSmokeTests -destination "platform=iOS Simulator,id=$simulator_id" CODE_SIGNING_ALLOWED=NO
