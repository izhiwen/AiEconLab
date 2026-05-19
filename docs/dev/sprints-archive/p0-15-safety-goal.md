# AEL #15 — P0 dogfood safety fix · CEO autonomous goal

Companion to the short `/goal` text. CEO reads this fully before starting.

## Mission

Close izhiwen/AiEconLab#15 (P0 safety: `aiplus add aieconlab` deletes tracked
`.aiplus/aieconlab/acceptance/v0.1.0/schema.yaml`). Ship two PRs serially:

- **Bundle R2 (AEL repo)**: move the acceptance schema out of the install
  target so the installer cannot harm it. Closes #15.
- **Bundle R1 (aiplus-public)**: teach the installer to refuse to delete
  git-tracked files. Defense in depth; benefits every future module.

R2 lands first and closes #15. R1 lands second and prevents recurrence
for any module. Both have independent QA; both must be green on 3
consecutive CI runs.

## Scope — strict

**Bundle R2 (AEL repo `~/Projects/AiEconLab`):**
- Move `.aiplus/aieconlab/acceptance/v0.1.0/schema.yaml` →
  `acceptance/v0.1.0/schema.yaml` (root-level `acceptance/` dir)
- Update path references in:
  - `.github/PULL_REQUEST_TEMPLATE.md` (lines 32–33)
  - `CONTRIBUTING.md` (line 20)
  - `DESIGN.md` (lines 4, 648)
  - `docs/TERMINOLOGY.md` (line 37)
  - `tests/acceptance.test.sh` (verify the loader path; note line 5
    currently references `agent-team` which is likely stale — fix if AEL)
  - `.github/workflows/ci.yml` (only if it references the schema path
    directly; it currently calls `tests/acceptance.test.sh` which loads
    the schema)
- Add regression test (new file under `tests/`):
  - `tests/regression_15_install_no_delete.sh` — fresh clone simulation:
    in a tmp dir, copy AEL repo content, run `aiplus install codex --yes
    && aiplus add aieconlab`, assert `git status --short | grep -E "^ D"
    | wc -l == 0` and the acceptance schema is still present
  - Wire into CI as a job in `.github/workflows/ci.yml`
- Anything else in AEL repo → out of scope

**Bundle R1 (aiplus-public `~/Dropbox/Project/AiPlus/aiplus-public`):**
- Modify `aiplus-cli` installer's reconcile/deletion code path. Before
  deleting any file, check if it is git-tracked in the project (use
  `git ls-files --error-unmatch <path>` or equivalent). If tracked,
  abort the deletion with a clear error message and a hint to file an
  issue if it should be in the bundled module manifest.
- Add regression test under
  `crates/aiplus-cli/tests/`: fake module with a "tracked but unmanaged"
  file, run `aiplus add fake-module`, assert no deletion + error message
- Update CHANGELOG with the safety guarantee
- Bundle does NOT change deletion behavior for untracked files (only
  protects git-tracked) — this avoids surprising behavior changes
- Anything else in aiplus-public → out of scope

## Bundles + ordering

- **Bundle R2** opens 1 PR on AEL repo; merges first; closes #15
- **Bundle R1** opens 1 PR on aiplus-public; starts AFTER R2 is
  merged (so R2's regression test in CI verifies R1's protection later);
  merges into aiplus-public main

R2 ETA: ~1h. R1 ETA: ~2-3h. Total sprint: half a day.

## Owner-gates (request in #15 first)

1. **G1 — new path confirm**: advisor recommends `acceptance/v0.1.0/`
   at AEL repo root. Owner may prefer `tests/acceptance/v0.1.0/` (groups
   with other tests) or `docs/acceptance/v0.1.0/` (treats schema as
   spec). Default to advisor recommendation if Owner silent past 24h.

That's the only Owner-gate. G1 default-resolves so the sprint can start
within 24h regardless.

## Execution loop

Same as Tier 1/1.5/2 — worktree isolation, dispatch `ra-python` builder,
independent QA from a different role (referee for R2 review, replicator
for R1 clean-env validation).

R2 worktree off latest AEL main; R1 worktree off latest aiplus-public main.

## Halt conditions

S1. 5 builder iter or 3 QA iter without green
S2. Scope creep beyond the file lists above
S3. Parallel session collision on either repo (HEAD switching, branch
    loss)
S4. Builder discovers the bug is actually somewhere else (e.g., AEL
    module manifest needs to whitelist the schema; the deletion is
    happening at a different code path than expected). HALT, ping
    Advisor with the new evidence; do not improvise a different fix.
S5. R2 regression test catches a NEW unrelated bug. Log it as a
    follow-up issue; do not expand sprint scope.

## Guardrails (never)

- Push to either repo's main directly (PRs only; Owner merges)
- Skip independent QA, even for 1-line changes
- Switch active team away from aieconlab (dogfood premise)
- `--no-verify`, `--no-gpg-sign`, force-push to main
- Modify the schema.yaml CONTENT during the move (file content stays
  byte-identical; only its path changes)

## Done

- D1. Bundle R2 PR merged into AEL main; independent QA PASS; #15
  closed via `Closes` keyword in PR body
- D2. Bundle R1 PR merged into aiplus-public main; independent QA PASS
- D3. Fresh clone test: `git clone izhiwen/AiEconLab tmp-test && cd
  tmp-test && aiplus install codex --yes && aiplus add aieconlab &&
  git status -s | grep -cE "^ D " == 0`. Paste transcript.
- D4. 3 consecutive same-HEAD green CI on both PRs (catches flakiness)
- D5. Consolidated summary on #15 with PR links, regression test
  output, dogfood transcript
- D6. Note in summary whether R1 makes the R2 fix theoretically
  redundant, AND whether R2 alone would have caught any other modules'
  similar latent bugs (advisor's hypothesis: yes both directions; CEO
  verifies)

## Anti-pattern reminders

- When halted (waiting on builder/CI/Owner), `sleep 600s` between
  re-checks. Do NOT tight-poll. After 6 idle cycles (~1h) without
  progress, exit autonomous goal — Owner re-triggers when ready.
- Don't misdiagnose: if the bug repros differently than #15 describes,
  STOP and ping Advisor before reframing.
- Don't try to invent tools that aren't exposed.

## Start

1. Read #15 fully + read this file fully
2. Post Owner-gate G1 question on #15
3. Open sub-issues for R2 and R1 with velocity estimates (link from #15)
4. `cd ~/Projects/AiEconLab && git checkout -b feat/p0-15-r2-acceptance-move`
5. Dispatch ra-python builder for Bundle R2
6. After R2 merges, repeat for R1 from aiplus-public worktree
7. Independent QA per bundle
8. Post final summary on #15

Memory: load `dev_roles`, `ceo_autonomous_goal_polling`, plus the new
`premature_infra_optimization` if it informs file/dir-naming taste.

Good hunting. — Advisor
