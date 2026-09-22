#!/usr/bin/env bash
# Writes an arm64 copy of a MediaPipeTasksCommon graph archive without the
# objects listed in config/excluded-graph-objects.txt.
# Usage: filter-graph-library.sh <input.a> <output.a>
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input="$1" output="$2"
mkdir -p "$(dirname "$output")"
# The simulator archive is fat; ar only edits thin archives and the wrapper
# is arm64-only anyway.
if lipo -info "$input" | grep -q '^Architectures in the fat file'; then
  lipo -thin arm64 "$input" -output "$output"
else
  cp "$input" "$output"
fi
members=$(ar t "$output")
excluded=()
while IFS= read -r object; do
  [[ -z "$object" || "$object" == \#* ]] && continue
  grep -qx "$object" <<< "$members" || { echo "Excluded object not found in $(basename "$input"): $object" >&2; exit 1; }
  excluded+=("$object")
done < "$root_dir/config/excluded-graph-objects.txt"
ar d "$output" "${excluded[@]}"
ranlib "$output" 2>/dev/null
echo "$(basename "$output"): dropped ${#excluded[@]} objects, $(ar t "$output" | wc -l | tr -d ' ') remain"
