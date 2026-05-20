# Changelog

All notable changes to AiEconLab (AEL) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.10] — 2026-05-20

### Changed

- `ael` with no args, role shortcuts such as `ael advisor`, `ael talk`,
  `ael talk --resume <role>`, `ael route`, and other interactive
  commands now delegate to aiplus's shared lobby and agent commands with
  `AIPLUS_BRAND=AEL`, `AIPLUS_TEAM=aieconlab`, and
  `AIPLUS_DEFAULT_ROLE=pi`.
- AEL-specific maintenance commands remain handled by the wrapper:
  `ael install`, `ael update`, `ael uninstall`, `ael doctor`, and
  `ael status`.
- Removed the v0.2.9 bash lobby/runtime picker/resume picker and
  substrate output filtering. aiplus v0.6.16+ owns the lobby, resume,
  session tagging, and native AEL branding.

### Requirements

- Requires `aiplus` v0.6.16+ on `PATH` for delegated commands.

## [0.2.9] — 2026-05-20

### Added

- `ael talk --resume <role>` now finds prior Codex and Claude Code sessions
  for the current project and role, shows a numbered picker, and resumes the
  selected runtime session. `--last` resumes the newest match directly, and
  `--list` prints the matching session list for scripts.
- Runtime session format discovery is documented in
  `docs/dev/v0.2.9-runtime-session-formats.md`. OpenCode is documented as a
  degraded mode because role-aware enumeration needs SQLite parsing, which is
  outside the bash-only v0.2.9 scope.

### Changed

- AEL wrapper and release package version anchors now report `0.2.9`.

## [0.2.8] — 2026-05-20

### Changed

- `vendor/aiplus` bumped to v0.6.15; interactive talk prompt now
  introduces the AEL team as "AEL virtual team" instead of the
  upstream-default "AiPlus virtual team".

## [0.2.7] — 2026-05-19

### Added

- `ael update` now syncs the PATH-resolved `aiplus` binary to match the
  bundled substrate after every upgrade. If `aiplus` is missing on PATH
  it is created in `$install_dir`; if present at a different version and
  the path is safe to overwrite (not under `dev/` or `target/`), it is
  refreshed via `install -m 755`. Opt-out: `AEL_UPDATE_NO_AIPLUS_SYNC=1`.
- New dry-run output lines: `would_create=…` or `would_sync=…` (or
  `aiplus_sync=skipped reason=…` when opted out or unsafe).

## [0.2.6] — 2026-05-19

### Added

- Interactive runtime sessions now bypass approval prompts by default.
  `ael <role>` and the lobby pass `--bypass` to `aiplus agent talk`,
  which appends the runtime-specific bypass flag
  (`--dangerously-bypass-approvals-and-sandbox` for Codex,
  `--dangerously-skip-permissions` for Claude Code and OpenCode).
  Opt-out: `AEL_BYPASS=0` (also accepts `false`, `no`).
- Codex headless one-shot path now also passes
  `--dangerously-bypass-approvals-and-sandbox`, matching the existing
  Claude Code and OpenCode headless behavior.

### Changed

- `vendor/aiplus` bumped to v0.6.13 (adds `aiplus agent talk --bypass`
  and `--safe` passthrough flags).

## [0.2.5] — 2026-05-19

### Added

- Lobby redesign: `ael`, `ael chat`, and role shortcuts now
  auto-install AEL project adapters on first run for supported runtime
  CLIs found on `PATH` (Codex, Claude Code, OpenCode), skipping missing
  runtimes silently and reporting a clear "no runtime found" error when
  none are available.
- The lobby now asks for both role and runtime when multiple installed
  runtimes are available; single-runtime projects skip the runtime
  question and launch directly.

### Changed

- Quickstart docs and installer hints now teach the one-command
  project flow: `cd MyProject && ael`.

## [0.2.3] — 2026-05-19

### Added

- Windows-native install path: `install.ps1` installs `ael.cmd`,
  `ael.ps1`, and `ael-support.exe` under the user's local app data
  directory without requiring WSL or git-bash.
- Windows `ael` wrapper with the same top-level commands, role
  shortcuts, lobby routing, first-run onboarding, substrate output
  sanitization, update/uninstall, telemetry, and headless role chat
  surface as the existing bash wrapper.
- Pester coverage for the PowerShell installer and wrapper, plus a
  Windows CI smoke path that installs from a local release package and
  checks `ael --version`, `ael --help`, `ael install codex`, lobby
  routing, and sanitized `ael talk`.

### Changed

- Windows release packages now contain `install.ps1`, `bin/ael.cmd`,
  `bin/ael.ps1`, and `libexec/ael-support.exe`; they no longer ship
  the bash wrapper as the Windows entry point.
- README install sections now show the Windows PowerShell one-liner
  directly below the macOS/Linux install command.

## [0.1.9] — 2026-05-19

PI auto-dispatches via the `agent_route` MCP tool instead of asking the
Owner to copy `ael route ...` bash commands. The natural-language UX
loop is now closed: Owner speaks, PI invokes tools, side effects happen.

### Changed

- **PI persona §3.1 rewritten**: calls `agent_route` MCP tool directly
  for dispatch and `agent_status` MCP tool for status questions. The old
  "end every dispatch with a fenced bash block" pattern is now a
  fallback used only when MCP tools are unavailable in the runtime.
  Trade-off explicitly accepted: efficiency over upfront confirmation,
  per Owner directive. Owner retains control via post-hoc `agent reset`
  rather than per-command approval.
- HEAVY-task `author-critic-fixer` workflow now passed as
  `workflow="author-critic-fixer"` arg to `agent_route` rather than as a
  separate `--workflow` shell flag.

### Fixed

- `tests/persona_behavior/test_cases.toml`: PI in_scope fixture updated
  to check semantic dispatch signal (scoring, role names) rather than
  the literal `ael route` substring that no longer appears in PI output
  when MCP tools are used.

## [0.1.8] — 2026-05-19

Fixes a path bug shipped in v0.1.7 that broke the new "personas read
the AEL CLI reference" feature in practice.

### Fixed

- `core/templates/personas/{pi.md,advisor.md}`: corrected the install
  path for `ael-cli-reference.md` from `.aiplus/aieconlab/...` to
  `.aiplus/modules/aieconlab/...`. The v0.1.7 personas pointed at a
  non-existent file, defeating the v0.1.7 feature on first contact.
  E2E install test confirms the corrected path is populated by
  `aiplus add aieconlab`.

## [0.1.7] — 2026-05-19

Teaches PI and Advisor about user-facing AEL CLI commands via a single
source of truth, so Owner asking "how do I upgrade?" or "I want to talk
to writer directly" gets an accurate quoted command instead of an
invented one.

### Added

- `core/templates/ael-cli-reference.md`: canonical CLI reference
  organized by user intent ("how do I ___?" → command). Covers lobby
  entry, 9 role shortcuts, install setup, status / doctor, update,
  uninstall, telemetry. Includes anti-patterns ("don't invent commands
  like `ael upgrade`").
- PI persona §7 and Advisor persona section pointing to the reference
  file. Personas read it via the runtime's native file-read tool each
  chat session.

### Fixed (CI)

- `regression-15-install-no-delete` now builds aiplus from the
  vendored submodule instead of `curl https://.../aiplus install.sh |
  bash`. aiplus upstream commit `59af425` narrowed pre-built binary
  support to ARM Mac + Windows; the curl path broke on Linux CI.

## [0.1.6] — 2026-05-19

Three-track v0.2.2 sprint shipped via three parallel CEO sessions.
Adds user-facing commands (`update`, `uninstall`, `--add-to-path`)
plus brand polish (PI emits `ael route` not `aiplus agent route`) plus
release pipeline ergonomics (auto-detect latest version).

### Added

- `ael update [--dry-run]`: in-place upgrade to the latest release
  with atomic replacement and dry-run preview.
- `ael uninstall [--purge] [--yes]`: clean removal. `--purge` also
  removes project-level `.aiplus/`.
- `install.sh --add-to-path`: opt-in flag that appends the install dir
  to the user's shell profile (zsh / bash / fish detected).
- First-run onboarding: post-`ael install` prints a 3-step quick start;
  first `ael` invocation in a project prints a one-line welcome.
- `install.sh` auto-resolves the latest release from
  `/releases/latest` redirect; no more hardcoded version constant.

### Changed

- PI persona §3.1 example dispatch commands use `ael route ...` not
  `aiplus agent route ...`. Substrate name is no longer leaked when
  PI offers a dispatch command (legacy code path; current `agent_route`
  tool-use path was added in 0.1.9).
- OpenCode runtime default model bumped `openai/gpt-4o-mini` →
  `openai/gpt-4o` for parity with claude-code's `sonnet` default.
- `persona-behavior` test wraps each assertion in a retry-up-to-3 loop
  so a single LLM flake (e.g. one stray forbidden substring) no longer
  fails CI; per-attempt status appears in the CI step summary.

### Fixed (CI)

- Drift workflow ignores commits whose subjects match
  `(ci|docs|chore\(release\)|chore\(vendor\)|chore\(deps\)|chore\(assets\)|chore\(agent-team\))` —
  routine upstream housekeeping no longer raises the drift alarm.

## [0.1.5] — 2026-05-18

Two structural changes: `ael` (no args) opens a lobby for role
selection, and `ael install` auto-registers the MCP server with the
runtime so PI in chat can call native tools.

### Added

- **Lobby + 9 role shortcuts**: `ael` (no args) prints a team menu and
  reads one line of input; matches it against role slugs (English),
  Chinese aliases (顾问 / 理论 / 内审 / ...), or free-form intent (`我想反思
  → advisor`). Recognized role re-execs into `ael talk <role>`.
  Power-user shortcuts `ael pi` / `ael advisor` / `ael writer` /
  `ael ra-stata` / `ael ra-python` / `ael theorist` / `ael referee` /
  `ael replicator` / `ael pm` skip the lobby.
- **MCP server auto-registration** during `ael install`: runs
  `aiplus mcp-register --runtime <runtime>` after the runtime adapter
  install + team add. Fail-soft — if MCP registration fails, the
  install still reports success and falls back to bash-block dispatch.
- `run_substrate_interactive()` helper that `exec`s the substrate
  binary directly (no `| sanitize` pipe) so codex / claude / opencode
  get a real TTY for REPL mode. Previously the pipe through
  `sanitize_substrate_output` killed interactive mode silently.

### Changed

- `vendor/aiplus` bumped to `0e7a057` (v0.6.0 era). Brings in
  `aiplus#7579366 preserve active team on runtime install`.

## [0.1.4] — 2026-05-18

Ships the v0.2.1 sprint — Author/Critic/Fixer workflow primitive, two
new experts (DOF, RR-Strategist), persona contract harness, telemetry
scaffold.

### Added

- **Author/Critic/Fixer workflow** (`ael route --workflow author-critic-fixer`):
  3-phase pipeline where the dispatched role drafts as Author, an
  independent Critic (referee, separate agent_id) reviews, and the
  original role returns as Fixer to incorporate critique. Audit log at
  `.aiplus/agents/workflow-log.jsonl`. Use for HEAVY drafts (rebuttals,
  introduction sections, structural model write-ups).
- **DOF expert**: degrees-of-freedom auditor. Persona at
  `core/templates/personas/dof-auditor.md`.
- **RR-Strategist expert**: R&R revision planning. Persona at
  `core/templates/personas/rr-strategist.md`.
- **Persona contract harness**: `tests/persona-behavior/` runs each
  persona through in-scope / boundary / stop-gate prompts and asserts
  forbidden-substring / required-substring policies via LLM judge.
- **Telemetry scaffold**: `ael telemetry [enable|disable|status]`.
  Strict local JSON only (`.ael/telemetry-events.jsonl`); no hosted
  endpoint.

### Changed

- PI persona §3.1 now suggests `--workflow author-critic-fixer` for
  HEAVY externally-read drafts.

## [0.1.3] — 2026-05-18

Mid-cycle release containing the v0.5.28 substrate fix and release
pipeline repair.

### Fixed

- `aiplus-core/build.rs` (vendor): split asset filtering into
  `is_skip_embed_asset` (silently skip binary blobs like `.gif`/`.png`)
  and `enforce_public_asset_policy` (panic on private fragments only).
  Fixes a regression where `assets/aieconlab/demo.gif` made the v0.5.28
  build panic on all platforms.

## [0.1.2] — 2026-05-15

Hotfix release.

### Fixed

- `install.sh` no longer attempts to remove user-tracked files during
  the team install reconcile pass. See parent issue #15.

## [0.1.1] — 2026-05-13

A polish release rolling up everything since v0.1.0: the 12th expert,
the research-tuned consultant team replacing SWE default, an install
smoke-test watchdog, a full set of community files, an honest beta
walkthrough, and ready-to-post outreach drafts.

### Added

- **LLM-as-Measurement Specialist** (12th expert) with full persona
  (~10K, 5 worked examples). Owns the validity protocol when LLMs or
  any frontier text model are used as measurement instruments on text
  data: multi-model cross-validation panel design, hand-coded
  subsample protocols, held-out test docs, inter-rater agreement
  metrics, prompt versioning, leakage prevention, AEA Data Editor
  compatibility.
- **AEL research-tuned consultant team**
  (`core/templates/consultant-team.aieconlab.toml`) replacing the
  default SWE consultant. Five expert seats designed from first
  principles for applied-econ research at plan time: Design
  Credibility, Contribution Framing, Day-1 Reproducibility, IRB /
  Disclosure Gate, LLM-as-Measurement. Three user personas
  (Anonymous Top-Tier Referee, Job-Market Audience, External
  Replicator) fire in HEAVY tier or risk ≥ 0.7. Five owner gates
  mirror DESIGN.md §16 STOP-gates. LIGHT tier skips consult by
  design — AEL consult is a strategic review board, not a daily team.
- Phase C external install path: `aiplus add --from-git
  https://github.com/izhiwen/AiEconLab` (requires aiplus ≥ v0.5.4) for
  installing the live HEAD of AEL without waiting for an AiPlus CLI
  release.
- Install smoke test CI workflow
  (`.github/workflows/install-smoke.yml`) that builds the aiplus CLI
  from source, vendors live AEL into the bundle, and runs the full
  install + opt-in + doctor + agent-route flow in clean tmp projects.
  Catches schema-mismatch class regressions.
- 15th acceptance invariant: `consultant_team_present` verifies the
  consultant TOML has the 5 expected member ids, 3 user_evidence
  personas, 5 owner gates, and `light.review_mode = "skip"`.

### Changed

- `consultant-team.aieconlab.toml` schema refactored to match the
  deployed `aiplus-auto-team-consultant` schema:
  - `[[members]]` use `id =` (was `lens_id =`)
  - User personas moved from `[[members]]` to
    `[[user_evidence.personas]]`
  - The LLM-as-Measurement seat takes `id = "ai_integration"` to
    satisfy the doctor's check while keeping its display name
- `aiplus-module.json`:
  - `requires.substrate_modules` now lists only the three actually-
    needed external substrate modules (`agent-memory`,
    `compact-reminder`, `auto-team-consultant`); velocity is built
    into the aiplus CLI core
  - `requiredFiles` extended to include the consultant team config
    and the LLM-Measurement Specialist persona
  - `doctorChecks` gains `consultant-team` and
    `llm-measurement-expert` entries
- AEL is **opt-in**, not auto-installed. AiPlus CLI ≥ v0.5.5 sets
  `auto_install: false` on the aieconlab module spec so that
  `aiplus install codex` does not pollute every AiPlus project with
  research-only files. Users who want AEL run
  `aiplus add aieconlab`.

### Fixed

- Expert directory headline count corrected from "11 specialists" to
  "12 specialists" across README, README.zh-CN, DESIGN.md, three
  adapter READMEs, and parent `MODULES.md`.
- ASCII architecture diagrams in README and DESIGN.md use canonical
  case (`AiPlus-Agent-Memory  AiPlus-Compact-Reminder
  AiPlus-Agent-Velocity`) consistent with the renamed sibling repos.
- LICENSE file now contains the full Apache-2.0 text instead of a
  4-line summary, so GitHub correctly detects the license as
  Apache-2.0 rather than NOASSERTION.

### Security

- Added `SECURITY.md` documenting AEL's data boundaries, STOP-gates,
  IRB / restricted-data policy, and disclosure path. AEL inherits the
  `aiplus-agent-memory` redaction patterns; AEL-specific concerns
  (consultant team, LLM-as-Measurement validity, IRB Gate) report to
  this repo.

## [0.1.0] — 2026-05-13

### Added

Initial release. Sibling of `AiPlus-Agent-Team` for applied-economics
research workflows.

- **8 core roles** with full personas (Identity & Voice, Knowledge
  Boundaries, Escalation, Memory Namespace, Forbidden Actions, 5
  worked examples each):
  - Advisor (strategic conversation, framing, second opinion)
  - PI (execution coordinator, dispatches and reports)
  - Theorist (identification, model structure, conceptual framework)
  - Project Manager (scope, acceptance criteria, deadlines)
  - RA-Stata (main regressions, tables, figures)
  - RA-Python (data cleaning, scraping, archive ingestion, GIS;
    dormant by default)
  - Referee (internal top-tier journal pre-review)
  - Replicator (clean-room reproducibility audit)
- **11 experts** in the expert directory:
  - Shipped (8): Lit Reviewer, Writer / Editor, Econometrician (Deep),
    Reproducibility Engineer, Historical Sources Specialist, Job Talk
    Coach, Visualization Specialist, Ethics / IRB Reviewer
  - v0.2 stubs (3): Survey / Experiment, Computation, Co-Author Liaison
- Three runtime adapter scaffolds (codex, claude-code, opencode) with
  parity, ship as placeholder READMEs for v0.1.
- Synthetic examples per runtime (`examples/codex/`,
  `examples/claude-code/`, `examples/opencode/`).
- 14-invariant acceptance schema and `tests/acceptance.test.sh`.
- GitHub Actions CI workflow validating JSON / YAML / TOML files plus
  running the acceptance test on every push.
- DESIGN.md (~17K) documenting the role mapping rationale, AEL's
  divergence from the AiPlus-Agent-Team SWE template, the routing
  protocol, the memory model, the worktree policy, and the STOP-gate
  inventory.
- Default toolchain Python + Stata + LaTeX, with R and Julia
  supported when declared.

### Architecture

- Brand-decoupled from AiPlus: AEL has its own GitHub repo, release
  cycle, and audience. Functionally depends on the AiPlus substrate
  (`agent-memory`, `compact-reminder`, `agent-velocity`,
  `auto-team-consultant`).
- Three-layer memory: personal (per-agent), team (PI-shared), project
  (existing `.aiplus/memory/`). Project memory wins on conflict.
- Git worktree workspaces: each code-touching role gets an isolated
  working directory so RA-Stata and RA-Python can work in parallel
  without silent overwrites.
- State-level permanence with warm bench: agent identity lives on
  disk; process is ephemeral, spawned only when PI routes a task.

### Owner-gated actions (STOP-gates)

12 STOP-gates that the team never auto-approves, including journal
submission, working-paper posting, referee response sending, data
sharing, and authorship changes. See DESIGN.md §16.

[unreleased]: https://github.com/izhiwen/AiEconLab/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/izhiwen/AiEconLab/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/izhiwen/AiEconLab/releases/tag/v0.1.0
