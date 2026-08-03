# x86_64 link-only stub

MediaPipe is built for arm64 only, but VCam ships as a universal
(arm64 + x86_64) app. `scripts/build-x86_64-stub.sh` builds the x86_64 slice
of the macOS framework from these sources so that universal apps can link
and launch; MediaPipe inference is intentionally unavailable in x86_64
processes (Intel Macs and Rosetta).

The stub does not depend on MediaPipe sources or headers: the class list is
generated from `macos/Headers` at build time, so upstream updates normally
require no changes here.
