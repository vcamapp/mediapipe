# Builder

The `MediaPipeTasksVisionWrapper.xcodeproj` is generated/maintained on an
Apple Silicon build host after `make fetch`. It links the arm64 device and
simulator slices of Google's official iOS binaries (the binary targets of
upstream's `Package.swift`) into the single dynamic framework. The
checked-in headers and force-link source define the public module surface,
and `MediaPipeTasksVision/ExportedSymbols.txt` limits the exported symbols to
that surface (`MPP*` classes and functions). Everything else in the
force-loaded graph library is dead-stripped, which keeps the LLM/text
tooling, ICU and tracing code bundled with the upstream binaries out of the
shipped binary. Objective-C classes survive regardless, so the other tasks'
Objective-C APIs bundled in upstream's `MediaPipeTasksCommon` (audio, text,
retrieval) stay in the binary; `scripts/validate.sh` fails if classes of SDKs
that App Store Connect rejects without a signature (ITMS-91065) appear.

`x86_64-stub/` provides the link-only x86_64 slice of the macOS framework
(see its README); it is built by `scripts/build-x86_64-stub.sh` and merged
with the arm64 framework by `scripts/create-xcframework.sh`.
