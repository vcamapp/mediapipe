# Builder

The `MediaPipeTasksVisionWrapper.xcodeproj` is generated/maintained on an
Apple Silicon build host after `make fetch`. Each slice links the static
library built from patched MediaPipe sources for its platform (iOS device,
iOS simulator, macOS; see `../source/README.md`) into a dynamic framework.
The in-repo headers (`../source/Headers`) and force-link source define the
public module surface, and `MediaPipeTasksVision/ExportedSymbols.txt` limits
the exported symbols to that surface (`MPP*` classes and functions); the
rest of the force-loaded archive is internal and dead-stripped where
unreachable. `scripts/validate.sh` fails if classes of SDKs that App Store
Connect rejects without a signature (ITMS-91065) appear.

`x86_64-stub/` provides the link-only x86_64 slice of the macOS framework
(see its README); it is built by `scripts/build-x86_64-stub.sh` and merged
with the arm64 framework by `scripts/create-xcframework.sh`.
