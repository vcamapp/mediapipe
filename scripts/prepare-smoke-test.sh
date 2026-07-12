#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resources="$root_dir/.build-artifacts/smoke-test-resources"
model_url="https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
model_sha256="fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
image_url="https://raw.githubusercontent.com/google-ai-edge/mediapipe-samples/3d23f0e459907af064c3e7494dbb180851e1694c/examples/hand_landmarker/android/app/src/androidTest/assets/test_image.jpg"
image_sha256="7584b748aa0c57a8cce3acd9e40149f5d4d7317f7db47c8a5a5f4a8fba9090ec"
mkdir -p "$resources"
curl --fail --location --retry 3 --output "$resources/hand_landmarker.task" \
  "$model_url"
curl --fail --location --retry 3 --output "$resources/hand.jpg" \
  "$image_url"
[[ -s "$resources/hand_landmarker.task" && -s "$resources/hand.jpg" ]] || { echo "Smoke resources are empty" >&2; exit 1; }
echo "$model_sha256  $resources/hand_landmarker.task" | shasum -a 256 -c -
echo "$image_sha256  $resources/hand.jpg" | shasum -a 256 -c -
