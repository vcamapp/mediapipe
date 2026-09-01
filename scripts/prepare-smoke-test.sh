#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/lib/models.sh"
resources="$root_dir/.build-artifacts/smoke-test-resources"

# <file name>|<source URL>|<sha256>
IMAGES=(
  "hand.jpg|https://raw.githubusercontent.com/google-ai-edge/mediapipe-samples/3d23f0e459907af064c3e7494dbb180851e1694c/examples/hand_landmarker/android/app/src/androidTest/assets/test_image.jpg|7584b748aa0c57a8cce3acd9e40149f5d4d7317f7db47c8a5a5f4a8fba9090ec"
  "pose.jpg|https://storage.googleapis.com/mediapipe-assets/pose.jpg|c8a830ed683c0276d713dd5aeda28f415f10cd6291972084a40d0d8b934ed62b"
  "face.jpg|https://storage.googleapis.com/mediapipe-assets/portrait.jpg|a6f11efaa834706db23f275b6115058fa87fc7f14362681e6abe14e82749de3e"
)

fetch() {
  local output="$resources/$1"
  curl --fail --location --retry 3 --output "$output" "$2"
  [[ -s "$output" ]] || { echo "Smoke resource is empty: $1" >&2; exit 1; }
  echo "$3  $output" | shasum -a 256 -c -
}

mkdir -p "$resources"
# The smoke tests run against the same models the package bundles.
model_entry() { fetch "$2.task" "$3" "$4"; }
for_each_model
for entry in "${IMAGES[@]}"; do
  IFS='|' read -r name url sha256 <<< "$entry"
  fetch "$name" "$url" "$sha256"
done
