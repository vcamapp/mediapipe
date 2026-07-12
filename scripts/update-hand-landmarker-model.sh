#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
models_dir="$root_dir/Sources/MediaPipeTasksVisionHandLandmarker/Resources/Models"
model_url="https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
expected_sha256="fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
output="$models_dir/hand_landmarker.task"

mkdir -p "$models_dir"
curl --fail --location --retry 3 --output "$output" "$model_url"
echo "$expected_sha256  $output" | shasum -a 256 -c -
