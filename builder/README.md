# Builder

The `MediaPipeTasksVisionWrapper.xcodeproj` is generated/maintained on an
Apple Silicon build host after `make fetch`. It links the arm64 device and
simulator CocoaPods slices into the single dynamic framework. The checked-in
headers and force-link source define the public module surface, and
`MediaPipeTasksVision/ExportedSymbols.txt` limits the exported symbols to that
surface (`MPP*` classes and functions). Everything else in the force-loaded
graph library is dead-stripped, which keeps the LLM/text tooling, ICU and
tracing code bundled with the upstream pod out of the shipped binary.
Objective-C classes survive a force-load regardless, so
`scripts/filter-graph-library.sh` first drops the objects listed in
`config/excluded-graph-objects.txt` (GTMSessionFetcher, GoogleToolboxForMac
and the internal telemetry client that is their only user) from the archive;
App Store Connect rejects binaries that embed those SDKs without a signature
(ITMS-91065), and `scripts/validate.sh` fails if their classes reappear.

`x86_64-stub/` provides the link-only x86_64 slice of the macOS framework
(see its README); it is built by `scripts/build-x86_64-stub.sh` and merged
with the arm64 framework by `scripts/create-xcframework.sh`.
