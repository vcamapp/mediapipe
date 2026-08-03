#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/config/versions.env"
stub_dir="$root_dir/builder/x86_64-stub"
out_dir="$root_dir/.build-artifacts/macos-stub"
obj_dir="$out_dir/obj"
binary="$out_dir/MediaPipeTasksVision"
rm -rf "$out_dir"
mkdir -p "$obj_dir"

ruby "$stub_dir/generate-stub-classes.rb" "$root_dir/macos/Headers" "$out_dir/MPPStubClasses.m"

target="x86_64-apple-macos${MINIMUM_MACOS_VERSION}"
for source in "$stub_dir/MPPStub.m" "$out_dir/MPPStubClasses.m"; do
  xcrun clang -target "$target" -fobjc-arc -Os -g -Wall -Werror \
    -I "$stub_dir" -c "$source" -o "$obj_dir/$(basename "${source%.m}").o"
done
# The install name must match the arm64 framework binary that this slice is
# lipo'd into (see scripts/create-xcframework.sh).
xcrun clang -target "$target" -dynamiclib \
  -install_name '@rpath/MediaPipeTasksVision.framework/Versions/A/MediaPipeTasksVision' \
  -compatibility_version 1 -current_version 1 \
  -framework Foundation \
  "$obj_dir"/*.o -o "$binary"
xcrun dsymutil "$binary" -o "$binary.dSYM"

for symbol in $REQUIRED_OBJC_CLASSES; do
  nm -gU "$binary" | grep -Fq "_OBJC_CLASS_\$_$symbol" || {
    echo "Stub is missing required class: $symbol" >&2
    exit 1
  }
done
lipo -info "$binary"
