#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/lib/models.sh"
mediapipe_version=$(sed -n 's/^MEDIAPIPE_VERSION="\([^"]*\)"/\1/p' "$root_dir/config/versions.env")

model_entry() {
  local models_dir="$root_dir/Sources/$1/Resources/Models"
  local model="$models_dir/$2.task"
  local metadata="$models_dir/$2.metadata.json"

  [[ -s "$model" && -s "$metadata" ]] || { echo "$2 model resources are missing" >&2; exit 1; }
  echo "$4  $model" | shasum -a 256 -c -
  ruby -rjson -e '
    metadata = JSON.parse(File.read(ARGV[0]))
    abort "Invalid model metadata" unless metadata["sha256"] == ARGV[1]
    abort "Unexpected model source URL" unless metadata["sourceURL"] == ARGV[2]
    abort "Unexpected tested MediaPipe version" unless metadata["testedMediaPipeVersion"] == ARGV[3]
    abort "Unexpected model license" unless metadata["license"] == "Apache-2.0"
  ' "$metadata" "$4" "$3" "$mediapipe_version"
}

for_each_model
