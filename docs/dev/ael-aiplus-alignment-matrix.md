# AEL / AiPlus Alignment Matrix

Date: 2026-05-22

Scope: AEL `main` at v0.3.0 after the AiPlus v0.7.5 vendor sync. This is a
planning document for the next wrapper-thinning pass; it is not a release plan.

## Alignment Rule

AEL must match AiPlus substrate behavior for every substrate-owned capability.
AEL may differ only in:

1. brand: AEL / AiEconLab
2. bundled team/module assets: `aieconlab`
3. role/persona content: PI, Advisor, RA, and other economics roles
4. `role_aliases`: economics and Chinese natural-language entry points
5. research-domain docs and examples

Every other difference is a bug unless Owner explicitly approves it.

## Current Command Surface

Public Unix wrapper help lists:

- `ael`
- `ael <role>`
- `ael talk`
- `ael route`
- `ael status`
- `ael doctor`
- `ael install`
- `ael update`
- `ael uninstall`
- `ael --version`

Supported but hidden or legacy Unix commands:

- `ael invite|dismiss|integrate`
- `ael substrate ...`
- `ael chat ...`
- `ael <single freeform input>`
- `ael <unknown multi-arg command ...>`

Windows wrapper note: Phase 2 cleanup 03 aligned the user-visible command
surface with Unix help, removed the local PowerShell headless-talk path, and
delegates the installed-project lobby to the substrate instead of running a
local PowerShell role router. `ael telemetry` was removed in the first Phase 2
cleanup patch.

## Matrix

| AEL command | Current AEL behavior | Corresponding AiPlus command | 100% delegate? | Allowed AEL differences | Current actual differences | Risk | Recommended action |
|---|---|---|---|---|---|---|---|
| `ael` | Unix ensures project setup, then execs bare `aiplus` lobby with `AIPLUS_BRAND=AEL`, `AIPLUS_TEAM=aieconlab`, `AIPLUS_DEFAULT_ROLE=pi`; Windows delegates to the bundled substrate lobby once the project is installed. | `aiplus` | Mostly | Brand, default team, first-run AEL greeting, econ role aliases/assets. | Windows still does not auto-install from bare `ael` the same way Unix does; install flow remains intentionally out of scope. | Medium | DELEGATE |
| `ael <role>` | Unix maps known econ roles to `aiplus agent talk --resume <role>` by default; `--fresh` strips the resume default and calls fresh talk. | `aiplus agent talk [--resume] <role>` | Yes | Econ role names and aliases. | AEL chooses resume as default for role shortcuts; this is product UX, not substrate semantics. | Low | KEEP_THIN |
| `ael <single freeform input>` | Unix maps one unknown non-flag argument to `aiplus agent talk <input>` so AiPlus `role_aliases` resolve it. | `aiplus agent talk <input>` | Yes | Econ/Chinese aliases live in `aieconlab` team config. | This intentionally prevents top-level `aiplus <cmd>` parsing for one-token unknowns; future commands like `refresh` need explicit cases. | Medium | KEEP_THIN |
| `ael talk` | Pass-through to `aiplus agent talk ...`; resume, dry-run, no-launch, runtime selection, and session lookup belong to AiPlus. | `aiplus agent talk ...` | Yes | Brand/team env and econ roles/personas. | Phase 2 cleanup 03 removed the Windows local runtime/headless prompt implementation. | Low | DELEGATE_DONE |
| `ael route` | Pass-through to `aiplus agent route ...`. | `aiplus agent route ...` | Yes | None beyond brand/team env and econ role names. | Queued/execution/lock/worktree semantics are wholly AiPlus-owned; AEL must not reinterpret route as executed work. | High if copied into personas/docs incorrectly | DELEGATE |
| `ael invite` | Hidden pass-through to `aiplus agent invite ...`. | `aiplus agent invite ...` | Yes | Econ roles only. | Hidden from Unix and Windows help. | Low | DELEGATE |
| `ael dismiss` | Hidden pass-through to `aiplus agent dismiss ...`. | `aiplus agent dismiss ...` | Yes | Econ roles only. | Hidden from Unix and Windows help. | Low | DELEGATE |
| `ael integrate` | Hidden pass-through to `aiplus agent integrate ...`. | `aiplus agent integrate ...` | Yes | Econ roles only. | Hidden from Unix and Windows help. | Low | DELEGATE |
| `ael status` | Unix calls bundled support as `aiplus agent status ...`. | `aiplus agent status ...` | Yes | Brand should say AEL/AiEconLab when invoked through AEL. | Output currently leaks `AiPlus Agent Team v0.1` and `aiplus agent set-team` wording. | High | WAIT_FOR_AIPLUS or AEL_BRAND_FIX |
| `ael doctor` | Runs `aiplus doctor ...`, then AEL-local PATH/bundled support drift checks and optional safe fix. | `aiplus doctor ...` plus AEL install-path check | No | AEL may check wrapper/support/PATH consistency and installed package drift. | Current hotfix correctly skips mismatch/downgrade when PATH `aiplus` is newer than bundled support. | Medium | KEEP |
| `ael update` | AEL self-update from AEL GitHub releases; dry-run reports wrapper/support replacement and PATH `aiplus` sync decision. | `aiplus update` is not equivalent | No | AEL release asset, wrapper path, support path, safe PATH `aiplus` sync. | Current hotfix correctly avoids downgrading newer PATH `aiplus`; this remains wrapper-owned. | Medium | KEEP |
| `ael uninstall` | Removes installed AEL wrapper/support; `--purge` removes project `.aiplus`. | `aiplus uninstall` is not equivalent | No | AEL install paths and explicit purge behavior. | Purge removes substrate project state; must stay explicit and not grow semantics. | Medium | KEEP |
| `ael install` | Local flow detects runtime, runs `aiplus install <runtime> --allow-version-skew`, `aiplus add aieconlab`, `aiplus agent set-team aieconlab`, and `aiplus mcp-register --runtime ...`; dry-run is local prose. | `aiplus install`, `aiplus add`, `aiplus agent set-team`, `aiplus mcp-register` | Not yet | AEL can choose `aieconlab` team/assets and supported runtimes. | AEL duplicates installer sequencing and dry-run wording; Windows and Unix implementations differ. | High | DELEGATE |
| `ael telemetry` | Removed; wrappers now return a clear removal error instead of writing local JSON. | None today; possible future `aiplus velocity` | No | Only if Owner later approves real AiPlus-backed research instrumentation. | Historical command had no demonstrated product value and created non-substrate semantics. | Low | DELETE_DONE |
| `ael refresh` | No explicit command. Because it is a single unknown token, Unix treats it as `aiplus agent talk refresh`; Windows treats it as `ael talk refresh`. | `aiplus refresh ...` | Should be yes once surfaced | Brand/help text only; all preservation semantics must come from AiPlus. | Dangerous future name collision: adding docs before wrapper case would route to talk, not refresh. | High for v0.7.6 UX | WAIT_FOR_AIPLUS |
| `ael memory ...` | No explicit command. Single `ael memory` routes to talk; multi-arg forms now return an AEL error. | `aiplus memory ...` | No public AEL wrapper now | AEL personas may instruct agents to use AiPlus memory primitives. | AEL should not invent memory CRUD. Prior `ael memory status` idea conflicts with the new alignment rule unless Owner approves. | Medium | WAIT_FOR_AIPLUS |
| `ael secret-broker ...` | No public wrapper. Single token routes to talk; multi-arg forms now return an AEL error instead of raw substrate passthrough. | `aiplus secret-broker ...` | No public AEL wrapper | Persona docs may mention AiPlus broker directly for agents. | AEL does not own secret semantics and must not wrap or alter them. | High | KEEP_HIDDEN |
| `ael substrate ...` | Hidden raw escape to bundled support binary. | `aiplus ...` | Yes, but intentionally hidden | Developer escape hatch only. | Can trigger substrate side effects under an AEL-looking command; Owner has approved keeping it hidden for now. | Medium | KEEP_DEV_ONLY |
| `ael chat` | No-argument lobby alias. `ael chat <args>` now errors with guidance to use `ael "..."` or `ael talk ...`. | `aiplus` lobby | Yes | None beyond brand/team/default role. | Unix and Windows now both reject chat arguments instead of silently passing or ignoring them. | Low | KEEP_LEGACY_ALIAS |
| `ael <unknown multi-arg command ...>` | Returns an AEL error with guidance to quote freeform input or use `ael talk ...`. | None | No | None. | Broad raw substrate passthrough removed in Phase 2 cleanup 02. | Low | DELETE_DONE |
| `ael --version` | Prints AEL version and minimum substrate floor, not actual PATH/bundled support version. | `aiplus --version` | No | AEL brand/version. | Version string says `aiplus 0.6.19+`; installed support may be 0.7.5. Useful but imprecise. | Low | KEEP |
| `ael --help` | Researcher-facing AEL help. | `aiplus --help` | No | Brand, econ roles, recommended research workflow. | Unix and Windows help surfaces are aligned after Phase 2 cleanup 03. | Low | KEEP_THIN |

## Special Checks

### Status Branding

Current source-wrapper `ael status` delegates to `aiplus agent status`, but the
output still starts with:

```text
AiPlus Agent Team v0.1
```

It also tells users to switch teams with `aiplus agent set-team ...`. This is a
branding gap because AEL is allowed to differ on brand. The preferred fix is in
AiPlus shared status via `AIPLUS_BRAND`; an AEL-side output filter should be a
last resort because the v0.2.10 cleanup deliberately removed substrate output
sanitization.

### Doctor / Update Downgrade Guard

The v0.3.0 hotfix is aligned with the matrix. AEL may own the wrapper/support
install path and PATH `aiplus` sync policy. Both `doctor` and `update` now treat
a newer PATH `aiplus` as acceptable and do not propose downgrading it to older
bundled support.

### Refresh

Future `ael refresh` must be an explicit thin proxy to `aiplus refresh ...`.
It must inherit AiPlus preservation semantics for memory, dispatch logs,
execution state, runtime logs, locks, lane worktrees, user files, and
non-managed blocks. Do not implement AEL refresh before AiPlus v0.7.6 refresh is
green and released. Also do not document `ael refresh` until the wrapper has an
explicit case, because today `ael refresh` routes to talk.

### Route

`ael route` must keep 100% of AiPlus route semantics: queued/executed wording,
lock behavior, worktree creation, dispatch logs, and status reporting. AEL
personas/docs may describe economic roles and artifacts, but must not promise
that `agent_route` already executed a worker unless AiPlus says so.

### Talk / Resume

`ael talk` and role shortcuts must inherit AiPlus behavior for `--resume`,
`--dry-run`, no-launch output, runtime selection, session lookup, and
role-alias resolution. Phase 2 cleanup 03 removed Windows local headless talk
and role-detection behavior from the installed-project lobby path.

### Memory

AEL should not add a separate memory command surface. Personas may instruct
agents to use `aiplus memory add/search` with economics-specific discipline, but
the storage, kinds, bridge behavior, and cross-role semantics are AiPlus-owned.
Do not unpark cross-runtime handoff without at least three transcript continuity
incidents.

### Secret Broker

AEL should not wrap or alter `aiplus secret-broker`. Personas may mention it as
the substrate primitive. AEL wrapper must not read, rotate, persist, or
reinterpret secrets.

### Telemetry

`ael telemetry` was removed because it was a local JSON toggle with no real
instrumentation value. A future instrumentation feature should delegate to an
AiPlus-owned primitive such as `aiplus velocity`.

## Phase 2 Cleanup Plan

### Order

1. Status brand decision and fix: prefer AiPlus shared status honoring
   `AIPLUS_BRAND`; only add AEL filtering if Owner explicitly accepts wrapper
   sanitization debt.
2. Add an explicit `refresh` case only after AiPlus v0.7.6 refresh is released:
   `ael refresh [args...]` -> `aiplus refresh [args...]`.
3. Delete accidental command paths: broad unknown multi-arg passthrough is done;
   keep `chat` as a no-argument legacy lobby alias; keep `substrate` hidden
   dev-only for now per Owner decision.
4. Thin `install`: replace local sequencing with the smallest possible AiPlus
   install/add/set-team/register delegation, retaining only AEL team selection,
   runtime detection if still necessary, and AEL-specific onboarding copy.
5. Keep `update`, `doctor`, `uninstall`, `--version`, and AEL help as explicit
   wrapper-owned surfaces.

### Wrapper Code To Delete

- Public `chat` alias after bare `ael` and freeform role aliases are verified
  across platforms, if Owner decides the legacy alias is no longer useful.
- Raw `substrate` user escape hatch only if Owner later revokes the hidden
  dev-only escape-hatch decision.
- Eventually delete bash / PowerShell `detect_role_from_input`, but not before
  the current dogfood validates `role_aliases` end-to-end.

### Wrapper Code To Keep

- AEL brand/team/default role environment setup.
- AEL self-update and package asset resolution.
- AEL wrapper/support install paths.
- PATH `aiplus` newer-version tolerance and safe overwrite checks.
- AEL uninstall paths and explicit `--purge`.
- AEL help and role shortcut UX.
- Bundled `aieconlab` assets, personas, aliases, docs, and examples.

### Wait For AiPlus

- v0.7.6 refresh MVP must be green and released before `ael refresh`.
- Status branding should ideally be fixed in AiPlus shared status.
- Route queued/execution/status wording belongs to AiPlus.
- Memory bridge and memory command semantics belong to AiPlus/persona
  discipline, not a new AEL wrapper command.

### Release Blockers

- `ael status` branding leak: `AiPlus Agent Team v0.1`.
- Any `ael refresh` release before AiPlus v0.7.6 refresh is released and AEL has
  an explicit thin delegate case.
- Any path that downgrades newer PATH `aiplus`; currently fixed, must stay
  covered.
- Windows wrapper still needs live PowerShell validation before public v1.0.

### v1.1 Follow-Up

- Decide whether researcher-visible velocity has a real job and, if so, wire it
  to AiPlus-owned `velocity` rather than local JSON toggles.
- Revisit cross-role memory bridge after dogfood produces enough continuity
  incidents; do not implement cross-runtime handoff from the current single
  incident.
- Consider an advanced help page for hidden AiPlus primitives instead of growing
  AEL's primary help.

## CEO Verdict

Plan ready. No substrate behavior should be changed from AEL for route, talk,
memory, secret-broker, refresh preservation, locks, worktrees, or runtime
selection. The next code pass should be a wrapper-thinning cleanup with explicit
Owner decisions on status branding and install thinning.
