#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root_dir/scripts/lib/models.sh"

model_entry() {
  local models_dir="$root_dir/Sources/$1/Resources/Models"
  local output="$models_dir/$2.task"

  mkdir -p "$models_dir"
  curl --fail --location --retry 3 --output "$output" "$3"
  echo "$4  $output" | shasum -a 256 -c -
}

for_each_model
