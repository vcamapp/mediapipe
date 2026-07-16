#!/usr/bin/env bash
# Builds MediaPipeTasksVision_macos.a (arm64, CPU-only) + flattened public
# headers from a patched google-ai-edge/mediapipe v0.10.35 checkout.
#
# Prerequisites:
#   - bazelisk (Bazel 7.4.1 is picked via .bazelversion)
#   - Xcode
#   - Statically built OpenCV referenced by the WORKSPACE macos_opencv repo
#     (build it first with build-macos-opencv.sh <work-dir> <prefix>)
#   - patches/*.patch applied to the checkout (git apply)
#   - external patches applied via WORKSPACE overrides (see README)
set -euo pipefail

# Resolve before any cd: BASH_SOURCE may be a path relative to the caller's
# working directory.
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="${1:?usage: $0 <mediapipe-src-dir> <out-dir>}"
out_dir="${2:?usage: $0 <mediapipe-src-dir> <out-dir>}"
# --remote_download_outputs=all: Bazel 7 defaults to "toplevel" (Build without
# the Bytes), which also applies to --disk_cache — on cache hits intermediate
# archives would never be materialized in bazel-out, corrupting the combine
# step below.
flags=(-c opt --config=darwin_arm64 --apple_generate_dsym=false --define MEDIAPIPE_DISABLE_GPU=1 --remote_download_outputs=all)
umbrella="//mediapipe/tasks/ios:MediaPipeTasksVision_macos"

cd "$src_dir"
mkdir -p "$out_dir"

# 1. Build the umbrella target (compiles the whole vision stack for macOS).
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
  -o "$out_dir/MediaPipeTasksVision_macos.a" -filelist "$out_dir/static_libs_abs.txt"

# 5. Collect the flattened public headers of the Vision framework via the
#    filegroup that patch 0004 adds next to the framework definition.
hdrs_target="//mediapipe/tasks/ios:MediaPipeTasksVision_macos_hdrs"
bazelisk build "${flags[@]}" "$hdrs_target"
mkdir -p "$out_dir/Headers"
bazelisk cquery "${flags[@]}" "$hdrs_target" --output=files 2>/dev/null \
  | while read -r header; do cp "$header" "$out_dir/Headers/"; done

# 6. Sanity checks. The required-class list lives in config/versions.env,
#    shared with scripts/validate.sh.
lipo -archs "$out_dir/MediaPipeTasksVision_macos.a" | grep -q arm64
if [[ -z "${REQUIRED_OBJC_CLASSES:-}" ]]; then
  source "$script_root/config/versions.env"
fi
: "${REQUIRED_OBJC_CLASSES:?set REQUIRED_OBJC_CLASSES or run from a repo checkout}"
symbols=$(nm -gU "$out_dir/MediaPipeTasksVision_macos.a" 2>/dev/null)
for sym in $REQUIRED_OBJC_CLASSES; do
  grep -q "OBJC_CLASS.._${sym}\$" <<< "$symbols" || { echo "missing symbol: $sym" >&2; exit 1; }
done
echo "OK: $out_dir/MediaPipeTasksVision_macos.a + Headers/"
