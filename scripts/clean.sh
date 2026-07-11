#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$root_dir/.build-artifacts" "$root_dir/builder/Pods" "$root_dir/builder/MediaPipeTasksVisionDependencies.xcodeproj" "$root_dir/builder/MediaPipeTasksVisionDependencies.xcworkspace"
