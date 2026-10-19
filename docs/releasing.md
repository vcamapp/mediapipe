# Releasing

There is a single user-facing release track: the versioned package releases,
which ship iOS and macOS together (one XCFramework, one `PACKAGE_VERSION`).
The `static-*` prereleases are internal build inputs only.

1. **Static libraries** (`MediaPipeTasksVision-<macos|ios|ios-simulator>-arm64-<MEDIAPIPE_VERSION>.zip`)
   on the `static-<MEDIAPIPE_VERSION>` prerelease — internal inputs to the
   package build, produced from source (see [`../source/README.md`](../source/README.md)).
   Not consumed by package users.
2. **The package itself** (`MediaPipeTasksVision.xcframework.zip`, containing
   the iOS device/simulator slices and the universal macOS slice — arm64
   implementation plus the x86_64 link-only stub from `builder/x86_64-stub`)
   on the `<PACKAGE_VERSION>` release — what `Package.swift` points at.

## 1. Static libraries (only when MediaPipe, OpenCV or the patches change)

`build.yml` is self-sufficient: when a pinned release asset is missing (a
fresh fork, or a just-bumped `MEDIAPIPE_VERSION`), it builds the static
libraries within the same run and continues, so pushes never fail on a
missing asset. Publishing the assets is an optimization that makes
subsequent CI runs fast and gives local `make fetch` something to download.
Changing a patch without bumping `MEDIAPIPE_VERSION` keeps the asset names, so
republish with `overwrite=true`.

Every build produces a different SHA-256 (archives embed timestamps); the
pins refer to the zips that are actually published. Only the run that
uploads determines the pins — SHA-256 values printed by `build.yml`'s
fallback builds are ephemeral and must not be committed.

1. Run the **“Static libraries”** workflow (`.github/workflows/static-artifacts.yml`)
   from the Actions tab. It builds the three libraries in parallel from
   upstream MediaPipe plus `source/patches/`, uploads the zips to the
   `static-<MEDIAPIPE_VERSION>` release, and **commits the new
   `*_ARTIFACT_SHA256` pins to the branch automatically**. Assets already
   published for the tag are kept as-is (pass `overwrite=true` to replace
   them, which re-pins). If a job warned that the generated headers differ,
   replace `source/Headers/` with the `Headers/` from its workflow artifact
   and commit.
2. The bot's pin commit does not trigger workflows itself; the next push (or
   the release workflow) exercises the fast download path.

`release.yml` intentionally requires the published, pinned assets — tags
should never be cut against artifacts that only ever existed inside one CI
run.

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
   uploads the release assets. It skips `static-*` tags, which belong to the
   static-library releases above.

## Version pins

All versions live in `config/versions.env`:

| Key | Meaning |
|---|---|
| `PACKAGE_VERSION` / `PACKAGE_BUILD` | SwiftPM package release and framework bundle version |
| `MEDIAPIPE_VERSION` | Upstream MediaPipe source tag every static library is built from |
| `MINIMUM_IOS_VERSION` / `MINIMUM_MACOS_VERSION` | Deployment targets, consumed by the build, validation, and smoke tests |
| `OPENCV_VERSION` | OpenCV statically linked into every static library |
| `STATIC_ARTIFACT_URL` / `MACOS_ARTIFACT_SHA256` / `IOS_ARTIFACT_SHA256` / `IOS_SIMULATOR_ARTIFACT_SHA256` | Pinned static library release assets |

`scripts/validate-versions.sh` cross-checks these against `Package.swift`,
`THIRD_PARTY_NOTICES.md`, the built frameworks, and the release notes;
`scripts/fetch.sh` verifies the static libraries against their pins;
`scripts/upstream-check.sh` additionally detects new upstream GitHub releases
and verifies that `source/patches/` still apply to the source tag.
