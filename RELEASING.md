# AEL Release Process

## Bumping Current Version

1. Edit `VERSION` to the target release version, for example `0.5.0`.
2. Run `bash scripts/verify-version-consistency.sh`.
3. Update `CHANGELOG.md` using the existing changelog format.
4. Commit, push, and open a release PR.
5. Wait for the version consistency lint and normal CI to pass before Owner merge.

`VERSION` is the single source of truth for the current AEL wrapper version.
Wrappers, package builds, and tests should read it instead of hardcoding an
`AEL X.Y.Z` current-version string.

## Bumping Minimum Supported Version

`$MinimumSupported` is not a routine release version. It is the oldest AEL
release that the installer or wrapper promises to self-upgrade from.

Bumping it means users on older AEL versions can no longer upgrade through the
new wrapper path. Change it only when consciously dropping support for an older
AEL release, and document the reason in `CHANGELOG.md` as a breaking change.

Current minimum-supported values live in `bin/ael.ps1` and `install.ps1`.
