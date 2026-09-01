# Task models bundled by the package, as
# <target>|<basename>|<source URL>|<sha256>.
#
# Update a model by bumping its URL and checksum here, then running
# scripts/update-models.sh.
MODELS=(
  "MediaPipeTasksVisionHandLandmarker|hand_landmarker|https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task|fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
  "MediaPipeTasksVisionPoseLandmarker|pose_landmarker_lite|https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task|59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a"
  "MediaPipeTasksVisionFaceLandmarker|face_landmarker|https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task|64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"
)

# Calls `model_entry <target> <basename> <url> <sha256>` for every model.
for_each_model() {
  local entry target basename url sha256
  for entry in "${MODELS[@]}"; do
    IFS='|' read -r target basename url sha256 <<< "$entry"
    model_entry "$target" "$basename" "$url" "$sha256"
  done
}
