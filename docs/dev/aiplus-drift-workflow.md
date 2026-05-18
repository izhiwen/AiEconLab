# AEL ↔ aiplus drift workflow

## Why this exists

AEL is a thin wrapper around the aiplus substrate. aiplus moves faster
than AEL — it gets bug fixes, new CLI subcommands, and template updates
on its own cadence. Without an automated drift report, AEL falls
silently behind: features the substrate ships are not reachable through
the `ael` wrapper, and Owner has to manually scan aiplus's commit log
to notice.

## What it does

`.github/workflows/aiplus-drift-check.yml` runs on three triggers:

1. **Weekly** (cron `0 9 * * MON` — Monday 09:00 UTC, ~17:00 China time)
2. **On-demand** via the GitHub Actions UI (`workflow_dispatch`)
3. **On aiplus release** via `repository_dispatch` (aiplus's release
   workflow will eventually call into AEL; not yet wired)

Each run:

1. Checks out AEL with `vendor/aiplus` submodule.
2. Fetches the latest 200 commits from aiplus `origin/main`.
3. Counts commits in `HEAD..origin/main` (where `HEAD` = the vendor
   pin).
4. If `count > 0`: builds an issue body listing every drifted commit
   and the suggested vendor-bump PR command. Upserts a single issue
   labeled `aiplus-drift`.
5. If `count == 0`: closes any open `aiplus-drift` issue with a comment.

## What Owner needs to do

Look at the `aiplus-drift` issue when it gets created or updated. Three
possible actions:

- **Bump now**: a fix or feature in those commits is user-relevant.
  Follow the suggested git commands in the issue. After CI passes and
  merge, cut the next AEL release.
- **Defer**: not user-relevant or not worth a release. Leave the issue
  open; the next week's run will refresh it.
- **Suppress**: if the commits will never matter (e.g. internal aiplus
  refactors), comment "ignoring" on the issue. The workflow will still
  upsert it, but you can ignore the noise.

## What this workflow does NOT do

- It does **not** auto-bump the vendor pin. Human decision required.
- It does **not** detect new aiplus CLI subcommands that AEL wrapper
  doesn't expose. That's a separate "command surface drift" check we
  may add later.
- It does **not** detect persona / template drift in
  `assets/aieconlab`, because AEL's release pipeline (`scripts/build-ael.sh`)
  rsyncs AEL into aiplus on every build — those snapshots are always
  freshly synced at release time.

## Future improvements

- Wire aiplus's `release.yml` to call into this workflow via
  `repository_dispatch` so a new aiplus release triggers an immediate
  drift report (rather than waiting until Monday).
- Add a second drift check that diffs `aiplus --help` output between
  vendor pin and origin/main, surfacing new top-level subcommands.
- Consider an auto-PR variant for patch-only releases (e.g. aiplus
  v0.5.28 → v0.5.29) where breaking change risk is low.
