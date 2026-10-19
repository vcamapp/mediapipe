#!/usr/bin/env bash
# Builds MediaPipeTasksVision_static.a for one platform (arm64, GPU-enabled:
# XNNPACK CPU + Metal delegate) + flattened public headers from a patched
# google-ai-edge/mediapipe checkout at the pinned MEDIAPIPE_VERSION.
#
# Prerequisites:
#   - bazelisk (it picks the Bazel version from upstream's .bazelversion)
#   - Xcode
#   - Statically built OpenCV for the same platform
#     (build it first with build-opencv.sh <platform> <work-dir> <prefix>)
#   - the platform's patches applied to the checkout (apply-patches.sh)
set -euo pipefail

# Resolve before any cd: BASH_SOURCE may be a path relative to the caller's
# working directory.
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$script_root/config/versions.env"
usage="usage: $0 <macos|ios|ios-simulator> <mediapipe-src-dir> <opencv-prefix> <out-dir>"
platform="${1:?$usage}"
src_dir="${2:?$usage}"
opencv_prefix="$(cd "${3:?$usage}" && pwd)"
out_dir="${4:?$usage}"
# --remote_download_outputs=all: Bazel 7 defaults to "toplevel" (Build without
# the Bytes), which also applies to --disk_cache — on cache hits intermediate
# archives would never be materialized in bazel-out, corrupting the combine
# step below.
flags=(-c opt --apple_generate_dsym=false --remote_download_outputs=all)
# The OpenCV repositories of the patched WORKSPACE (patches 0001 and 0011) and
# the LC_BUILD_VERSION platform the archive must carry.
case "$platform" in
  macos)
    flags+=(--config=darwin_arm64)
    opencv_link=third_party/opencv_static
    build_platform=MACOS
    ;;
  ios)
    # OPENCV=source routes //third_party:opencv to @ios_opencv_static.
    flags+=(--config=ios_arm64 --ios_minimum_os="$MINIMUM_IOS_VERSION" --define=OPENCV=source)
    opencv_link=third_party/opencv_ios_static
    build_platform=IOS
    ;;
  ios-simulator)
    flags+=(--config=ios_sim_arm64 --ios_minimum_os="$MINIMUM_IOS_VERSION" --define=OPENCV=source)
    opencv_link=third_party/opencv_ios_simulator_static
    build_platform=IOSSIMULATOR
    ;;
  *) echo "$usage" >&2; exit 1 ;;
esac
umbrella="//mediapipe/tasks/ios:MediaPipeTasksVision_static"

cd "$src_dir"
mkdir -p "$out_dir"
ln -sfn "$opencv_prefix" "$opencv_link"

# 1. Build the umbrella target (compiles the whole vision stack).
bazelisk build "${flags[@]}" "$umbrella"

# 2. Enumerate the transitive static libraries.
starlark=$(mktemp)
cat > "$starlark" <<'EOF'
def format(target):
    libs = []
    for li in providers(target)["CcInfo"].linking_context.linker_inputs.to_list():
        for lib in li.libraries:
            if lib.static_library:
                libs.append(lib.static_library.path)
            elif lib.pic_static_library:
                libs.append(lib.pic_static_library.path)
    return "\n".join(libs)
EOF
bazelisk cquery "${flags[@]}" "$umbrella" \
  --output=starlark --starlark:file="$starlark" 2>/dev/null \
  | grep -v '^$' | sort -u > "$out_dir/static_libs.txt"

# MediaPipe 1.0.0 pulls zlib twice under hybrid WORKSPACE/bzlmod resolution
# (external/zlib from WORKSPACE and external/zlib~ from the module graph).
# Keep the module copy and drop the WORKSPACE one to avoid duplicate symbols
# in the combined archive.
if grep -q 'external/zlib~/libz\.a' "$out_dir/static_libs.txt"; then
  grep -v 'external/zlib/libzlib\.a' "$out_dir/static_libs.txt" > "$out_dir/static_libs.txt.tmp"
  mv "$out_dir/static_libs.txt.tmp" "$out_dir/static_libs.txt"
fi

# 3. Materialize every dependency archive: linking the throwaway dylib that
#    patch 0004 defines makes all of them link inputs, so Bazel is forced to
#    produce each one (and verifies the symbol graph is complete).
bazelisk build "${flags[@]}" "$umbrella"_link_check

# 4. Combine into a single archive. Paths under external/ (e.g. the static
#    OpenCV archives) live in Bazel's output base, not the workspace.
#    libtool silently skips missing entries, which would corrupt the archive —
#    verify every path first.
output_base=$(bazelisk info output_base)
awk -v ws="$PWD" -v ob="$output_base" \
  '{ if ($0 ~ /^external\//) print ob "/" $0; else print ws "/" $0 }' \
  "$out_dir/static_libs.txt" > "$out_dir/static_libs_abs.txt"
missing=0
while IFS= read -r lib; do
  [[ -f "$lib" ]] || { echo "missing archive: $lib" >&2; missing=$((missing + 1)); }
done < "$out_dir/static_libs_abs.txt"
[[ "$missing" -eq 0 ]] || { echo "$missing archives were not materialized; aborting." >&2; exit 1; }
libtool -static -no_warning_for_no_symbols \
  -o "$out_dir/MediaPipeTasksVision_static.a" -filelist "$out_dir/static_libs_abs.txt"

# 5. Collect the flattened public headers of the Vision framework via the
#    filegroup that patch 0004 adds next to the framework definition.
hdrs_target="//mediapipe/tasks/ios:MediaPipeTasksVision_static_hdrs"
bazelisk build "${flags[@]}" "$hdrs_target"
mkdir -p "$out_dir/Headers"
bazelisk cquery "${flags[@]}" "$hdrs_target" --output=files 2>/dev/null \
  | while read -r header; do cp "$header" "$out_dir/Headers/"; done

# 6. Sanity checks. The required-class list lives in config/versions.env,
#    shared with scripts/validate.sh.
lipo -archs "$out_dir/MediaPipeTasksVision_static.a" | grep -q arm64
# A member built for another platform (e.g. a mislinked OpenCV prefix) links
# with only a warning but fails at run time.
platforms=$(otool -lv "$out_dir/MediaPipeTasksVision_static.a" | awk '/cmd LC_BUILD_VERSION/ {getline; getline; print $2}' | sort -u | xargs)
[[ "$platforms" == "$build_platform" ]] || { echo "unexpected build platforms: $platforms (want $build_platform)" >&2; exit 1; }
symbols=$(nm -gU "$out_dir/MediaPipeTasksVision_static.a" 2>/dev/null)
for sym in $REQUIRED_OBJC_CLASSES; do
  grep -q "OBJC_CLASS.._${sym}\$" <<< "$symbols" || { echo "missing symbol: $sym" >&2; exit 1; }
done
echo "OK: $out_dir/MediaPipeTasksVision_static.a + Headers/"
