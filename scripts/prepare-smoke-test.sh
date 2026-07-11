#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resources="$root_dir/.build-artifacts/smoke-test-resources"
mkdir -p "$resources"
curl --fail --location --retry 3 --output "$resources/hand_landmarker.task" \
  "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
curl --fail --location --retry 3 --output "$resources/hand.jpg" \
  "https://raw.githubusercontent.com/google-ai-edge/mediapipe-samples/main/examples/hand_landmarker/android/app/src/androidTest/assets/test_image.jpg"
[[ -s "$resources/hand_landmarker.task" && -s "$resources/hand.jpg" ]] || { echo "Smoke resources are empty" >&2; exit 1; }
