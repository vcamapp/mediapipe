#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model="$root_dir/Sources/MediaPipeTasksVisionHandLandmarker/Resources/Models/hand_landmarker.task"
metadata="$root_dir/Sources/MediaPipeTasksVisionHandLandmarker/Resources/Models/hand_landmarker.metadata.json"
expected_sha256="fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"

[[ -s "$model" && -s "$metadata" ]] || { echo "Hand Landmarker model resources are missing" >&2; exit 1; }
echo "$expected_sha256  $model" | shasum -a 256 -c -
ruby -rjson -e '
  metadata = JSON.parse(File.read(ARGV[0]))
  abort "Invalid model metadata" unless metadata["sha256"] == ARGV[1]
  abort "Unexpected tested MediaPipe version" unless metadata["testedMediaPipeVersion"] == ARGV[2]
  abort "Unexpected model license" unless metadata["license"] == "Apache-2.0"
' "$metadata" "$expected_sha256" "$(sed -n 's/^MEDIAPIPE_VERSION="\([^"]*\)"/\1/p' "$root_dir/config/versions.env")"
