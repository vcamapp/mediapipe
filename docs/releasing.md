# Releasing

There is a single user-facing release track: the versioned package releases,
which ship iOS and macOS together (one XCFramework, one `PACKAGE_VERSION`).
The `macos-*` prereleases are internal build inputs only.

1. **macOS static library** (`MediaPipeTasksVision-macos-arm64-<MEDIAPIPE_VERSION>.zip`)
   on the `macos-<MEDIAPIPE_VERSION>` prerelease — an internal input to the
   package build, produced from source (see [`../macos/README.md`](../macos/README.md)).
   Not consumed by package users.
2. **The package itself** (`MediaPipeTasksVision.xcframework.zip`, containing
   the iOS device/simulator and macOS slices) on the `<PACKAGE_VERSION>`
   release — what `Package.swift` points at.

## 1. macOS static library (only when MediaPipe or the patches change)

`build.yml` is self-sufficient: when the pinned release asset is missing (a
fresh fork, or a just-bumped `MEDIAPIPE_VERSION`), it builds the static
library within the same run and continues, so pushes never fail on a missing
asset. Publishing the asset is an optimization that makes subsequent CI runs
fast and gives local `make fetch` something to download:

Every build produces a different SHA-256 (archives embed timestamps); the pin
refers to the one zip that is actually published. Only the run that uploads
determines the pin — SHA-256 values printed by `build.yml`'s fallback builds
are ephemeral and must not be committed.

1. Run the **“macOS build dependency”** workflow (`.github/workflows/macos-artifact.yml`)
   from the Actions tab. It builds the library from upstream MediaPipe plus
   `macos/patches/`, uploads the zip to the `macos-<MEDIAPIPE_VERSION>`
   release, and **commits the new `MACOS_ARTIFACT_SHA256` pin to the branch
   automatically**. If an asset is already published for the tag it is kept
   as-is (pass `overwrite=true` to replace it, which re-pins). If the job
   warned that the generated headers differ, replace `macos/Headers/` with the
   `Headers/` from the workflow artifact and commit.
2. The bot's pin commit does not trigger workflows itself; the next push (or
   the release workflow) exercises the fast download path.

`release.yml` intentionally requires the published, pinned asset — tags should
never be cut against an artifact that only ever existed inside one CI run.

## 2. Package release

### CI-driven (recommended)

Run the **“Release”** workflow (`.github/workflows/release.yml`) from the
Actions tab with the new version (e.g. `0.1.0`). In a single run it builds the
package, writes `PACKAGE_VERSION` and the `Package.swift` URL/checksum pins,
commits, tags that commit, pushes, and publishes the release with the very
artifacts it built — so the tagged commit is self-consistent by construction
and no local build is involved. It refuses to run if the tag or release
already exists.

### Manually (equivalent)

1. Bump `PACKAGE_VERSION` in `config/versions.env`.
2. Build and verify locally:
   ```bash
   make all
   ```
   `package` writes the reproducible zip and its checksum to
   `.build-artifacts/checksums.txt`.
3. Update the `binaryTarget` in `Package.swift`: the release-URL version and
   the `checksum` (first line of `checksums.txt`).
4. Commit, tag with the package version, and push the tag. `release.yml`
   rebuilds, verifies that the rebuilt checksum matches `Package.swift`, and
   uploads the release assets. It skips `macos-*` tags, which belong to the
   static-library releases above.

## Version pins

All versions live in `config/versions.env`:

| Key | Meaning |
|---|---|
| `PACKAGE_VERSION` / `PACKAGE_BUILD` | SwiftPM package release and framework bundle version |
| `MEDIAPIPE_VERSION` | Upstream MediaPipe (CocoaPods for iOS, source tag for macOS) |
| `MINIMUM_IOS_VERSION` / `MINIMUM_MACOS_VERSION` | Deployment targets, consumed by the build, validation, and smoke tests |
| `OPENCV_VERSION` | OpenCV statically linked into the macOS artifact |
| `MACOS_ARTIFACT_URL` / `MACOS_ARTIFACT_SHA256` | Pinned macOS static library release asset |

`scripts/validate-versions.sh` cross-checks these against `Package.swift`,
`Podfile.lock`, the built frameworks, and the release notes;
`scripts/upstream-check.sh` additionally detects new upstream releases and
verifies that `macos/patches/` still apply to the pinned tag.
