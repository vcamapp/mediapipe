# Names and pins of the per-platform static library zips (config/versions.env).
# Source config/versions.env first.
STATIC_PLATFORMS=(macos ios ios-simulator)

static_artifact_name() {
  echo "MediaPipeTasksVision-$1-arm64-$MEDIAPIPE_VERSION.zip"
}

static_artifact_sha256() {
  case "$1" in
    macos) echo "$MACOS_ARTIFACT_SHA256" ;;
    ios) echo "$IOS_ARTIFACT_SHA256" ;;
    ios-simulator) echo "$IOS_SIMULATOR_ARTIFACT_SHA256" ;;
    *) echo "Unknown platform: $1" >&2; return 1 ;;
  esac
}

# The config/versions.env key that pins the platform's zip.
static_artifact_sha256_key() {
  case "$1" in
    macos) echo MACOS_ARTIFACT_SHA256 ;;
    ios) echo IOS_ARTIFACT_SHA256 ;;
    ios-simulator) echo IOS_SIMULATOR_ARTIFACT_SHA256 ;;
    *) echo "Unknown platform: $1" >&2; return 1 ;;
  esac
}
