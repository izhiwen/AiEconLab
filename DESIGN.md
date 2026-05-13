# AiEconLab Design

Status: draft v0.1.0
Acceptance schema (binding): `.aiplus/aieconlab/acceptance/v0.1.0/schema.yaml`
Scope: local-first permanent applied-economics research team, with adaptive
coordinator and on-demand expert directory, designed to compose with the
existing AiPlus plugin stack.

This document is the sibling of `aiplus-agent-team`'s DESIGN.md. The
underlying mechanisms (permanence model, worktrees, three-layer memory,
coordinator scoring) are identical and we cite the sibling rather than
re-deriving. The role structure, expert directory, and workflow examples
are specific to applied economics research.

---

## 1. One-Line Positioning

`aieconlab` installs a permanent virtual team of AI research
agents into a project so that an Owner (lead author / PI) can run a
multi-role applied-economics research organization with two human-facing
entry points (Advisor and PI) and an adaptive set of internal specialists,
all without leaving the local machine.

In plain language:

> A single AI agent in a long session forgets, drifts roles, and pollutes
> its memory across unrelated tasks. AiEconLab replaces that
> single agent with a small standing research team — Advisor, PI, Theorist,
> PM, RA-Stata, RA-Python, Referee, Replicator — each with its own
> workspace, memory, and persona, plus an on-demand expert directory the PI
> can pull from when a paper warrants it. The Owner only talks to Advisor
> and PI; the PI orchestrates the rest.

---

## 2. Problem

A real economics-research Owner running AI coding agents day to day hits
three recurring failures:

1. **Roles drift inside one agent.** A single session is asked to scope a
   paper, then clean data, then run identification, then write the
   introduction, then prepare a referee response. The same prompt-history
   blends research intuition, Stata syntax, lit-review fragments, and
   rebuttal language. The agent quietly slips out of one role into the next
   and produces output that is none of them well.

2. **Memory pollution.** A single shared memory means the Theorist's
   framing leaks into the RA's regression spec, lit-review notes get buried
   under debug printlns from data cleaning, robustness checks age out of
   the window because of irrelevant scratch.

3. **No serious division of labor.** Real research projects have a PI, a
   theorist who owns identification, RAs who run code, a writer who
   polishes prose, internal pre-review, and a replicator because the work
   *is* that structured. Forcing one agent to wear all hats means it does
   each hat shallowly.

The existing AiPlus plugins each address part of the problem:

- `aiplus-agent-memory` gives one agent a clean, project-local memory.
- `AiPlus-Compact-Reminder` cuts one agent's token burn via structured compact + resume.
- `aiplus-auto-team-consultant` consults a virtual expert team *before* a
  plan is written, but does not execute and does not persist.
- `aiplus-agent-velocity` calibrates one agent's estimates.
- `aiplus-agent-team` is the sibling for software engineering; this is
  the sibling for applied-economics research.

`aieconlab` is the role-and-execution layer for research.

---

## 3. What This Plugin Is Not

To prevent scope drift, four explicit non-goals:

1. **Not a virtual consultant.** That is `aiplus-auto-team-consultant`.
   Consultant *advises* the PI before a plan; team *executes* the plan.
   A team member is a real persistent agent that touches files and runs
   code; a consultant lens fires only at planning time and never owns code.

2. **Not a multi-process daemon.** The team is State-level permanent (see
   sibling DESIGN.md §6), not process-level permanent. No daemon, no IPC.

3. **Not a remote-execution platform.** All agents run inside the Owner's
   existing host runtime (Codex, Claude Code, OpenCode). Nothing uploads,
   nothing syncs to cloud, nothing runs on someone else's machine.

4. **Not a replacement for Owner judgment.** STOP-gated actions (journal
   submission, working-paper posting, referee response sending, data
   sharing, authorship changes) always escalate to the Owner. The team can
   prepare and recommend, but never auto-approve.

---

## 4. Solution Overview — Five Core Decisions

The plugin rests on five architectural decisions, each consciously chosen
over plausible alternatives:

1. **Permanent core team of 8 roles**, installed automatically when the
   plugin is added to a project (§5).
2. **Expert directory** of 11 specialist roles available on-demand, only
   summoned when triggers match (§5.3).
3. **State-level permanence + warm bench** (not process-level daemon, not
   pure ephemeral) — agent identity lives on disk, fast cache for repeat
   calls. Identical to sibling agent-team.
4. **Git worktree workspaces** (not shared branches, not folder copies) —
   parallel, conflict-tracked, atomically revertible. Identical to sibling.
5. **Three-layer memory** (personal / team / project) with project as the
   most authoritative layer. Identical to sibling.

A sixth design ingredient — the adaptive coordinator inside the PI — is
not a new invention but a **reuse** of `aiplus-auto-team-consultant`'s
scoring + scaling rules (§9). One algorithm covers consult-time decisions
and execute-time staffing.

---

## 5. Team Structure

### 5.1 Owner-Facing Tier (always 2)

| Role | Responsibility | Default invocation |
|---|---|---|
| **Advisor** | Strategic conversation. *Decides what to do.* Decision support, second opinion, tradeoff explanation, framing. | Owner directly |
| **PI** | Execution coordination. *Gets it done and reports.* Receives tasks, scores, dispatches, integrates, reports back. | Owner directly |

The Owner sees only these two by default. As a clean rule of thumb:

- "Should I do X or Y?" / "Is this paper QJE-shaped?" → **Advisor**
- "Do X" / "What's the status of X?" / "Is the AER R&R done yet?" → **PI**
  (status questions stay with PI even when they sound like Advisor; PI owns
  the source of truth for in-flight work).

### 5.2 Internal Core Team (always 6)

| Role | Responsibility | Default state |
|---|---|---|
| **Theorist** | Identification, model structure, the conceptual frame that connects research question to estimable equation | Active |
| **PM** | Scope, acceptance criteria, deadlines (editor R&R, conference, seminar, working-paper post), timeline | Active |
| **RA-Stata** | Stata implementation. Main regressions, tables, figures. Default specialty: main-regressions-and-tables. | Active |
| **RA-Python** | Python implementation. Data cleaning, scraping, archive ingestion, GIS, panel construction. **Dormant by default**; activates only when PI explicitly parallelizes (HEAVY tier or Owner request, or when a project is data-heavy). | Dormant unless invoked |
| **Referee** | Internal pre-review against top-5 or field-top journal templates; surfaces the comment a real referee will write before they write it | Active |
| **Replicator** | Clean-room reproducibility audit; pins versions, seeds, dataset hashes; catches the moment a Stata bump or package drift silently changes a coefficient | Active |

Total core team = 2 owner-facing + 6 internal = **8 roles**.

### 5.3 Expert Directory (on-demand, not core)

Eleven specialists are pre-defined and ready to summon. **For v0.1, eight
"high-frequency" experts ship implemented; the remaining three ship as
config stubs and become functional in v0.2.** All are State-level permanent
(persona, memory, workspace template exist as files), but only enter a
project's *active* team when summoned.

| Expert | Trigger conditions | v0.1 status |
|---|---|---|
| **Lit Reviewer** | `literature`, `prior work`, `citation`, `bib`, `lit map`, `placement` | shipped |
| **Writer / Editor** | `intro`, `abstract`, `rebuttal`, `rewrite`, `copy edit`, paper-prose-bearing task | shipped |
| **Econometrician (Deep)** | `identification` (deep), `IV` (deep), `DID` (estimator-frontier), `RD`, `SE`, `clustering`, `inference`, `weak instrument` | shipped |
| **Reproducibility Engineer** | `docker`, `seed`, `pin`, `Makefile`, `CI`, `dvc`, `env` | shipped |
| **Historical Sources Specialist** | `archive`, `gazetteer`, `treaty port`, `dynasty`, `OCR`, `historical`, `manuscript` | shipped |
| **Job Talk Coach** | `job talk`, `seminar`, `talk prep`, `job market` | shipped |
| **Visualization Specialist** | `figure`, `plot`, `map`, `color`, `ggplot`, `tikz`, `chart polish` | shipped |
| **Ethics / IRB Reviewer** | `irb`, `consent`, `pii`, `anonymization`, `restricted data`, `dua` | shipped |
| **Survey / Experiment Specialist** | `RCT`, `survey`, `lab`, `field experiment`, `power analysis`, `pre-registration` | v0.2 stub |
| **Computation Specialist** | `HPC`, `cluster`, `parallel`, `big data`, `bootstrap` (large), `simulation` (heavy) | v0.2 stub |
| **Co-Author Liaison** | `co-author`, `authorship`, `attribution`, `division of labor`, `joint work` | v0.2 stub |

A summon is reversible — when the project no longer needs the expert, the
PI drops it via `aiplus agent dismiss`. State files remain on disk.

### 5.4 Recommended Initial Activation by Project Type

| Project type | Core 8 + summoned experts |
|---|---|
| Econ history (archival) | + Historical Sources + Lit Reviewer + Reproducibility |
| Development / political econ (panel) | + Lit Reviewer + Econometrician + Reproducibility |
| RCT / field experiment | + Survey / Experiment (v0.2) + Ethics / IRB (v0.2) + Lit Reviewer |
| Structural / IO | + Econometrician + Computation (v0.2) + Reproducibility |
| Empirical asset pricing | + Econometrician + Computation (v0.2) + Reproducibility |
| Pre-submission round (any paper) | + Writer + Referee already core + Reproducibility |
| Job-market push | + Job Talk Coach + Writer |
| Co-authored project | + Co-Author Liaison (v0.2) + Lit Reviewer |

---

## 6. Permanence Model: State + Warm Bench

Identical to sibling agent-team. Summary:

An agent is **State-level permanent**: its persona, memory, workspace, and
last-known state live as files on disk. The agent process itself is
ephemeral — spawned on demand, runs the task, writes new state to disk,
exits.

The warm bench is a hot cache for repeat calls — the PI is most-recently-used,
RA-Stata next, etc. Warm bench TTL is configurable per role (see role
`.toml` `warm_bench_ttl_seconds`). RAs default to 30 minutes; owner-facing
roles default to 60 minutes.

For full rationale, see sibling DESIGN.md §6.

---

## 7. Worktree Workspace Policy

Identical to sibling agent-team. Summary:

Each code-touching role gets an isolated git worktree:

- `agent/theorist` — Theorist's spec notes, theory drafts
- `agent/pm` — PM's scope memos, Gantt drafts
- `agent/ra-stata` — RA-Stata's `.do` files, log outputs
- `agent/ra-python` — RA-Python's cleaning pipelines
- `agent/referee` — Referee's pre-review notes
- `agent/replicator` — Replicator's run logs and env snapshots

Advisor and PI do not need worktrees — they coordinate, they do not write
artifact code.

RA-Stata and RA-Python can work in parallel on different branches without
silent overwrites; conflicts surface through git merge.

PI integrates branches via `aiplus agent integrate <role>`. Branches that
fail integration are flagged but not silently dropped.

For full policy, see sibling DESIGN.md §7.

---

## 8. Three-Layer Memory Model

Identical to sibling agent-team. Summary:

- **Personal** (`.aiplus/agent-memory/<role>/`): each agent's private
  notes, dispatch log, calibration data. Only that agent writes.
- **Team** (`.aiplus/agent-memory/_team/`): shared decisions. Only PI and
  PM write. Everyone reads.
- **Project** (`.aiplus/memory/`): durable project consensus. Only Owner
  writes (via existing `aiplus-agent-memory` flow). Everyone reads.

Conflict resolution: **project wins over team wins over personal**. A
team-of-the-day decision never overrides durable project consensus.

Research-specific entries that go in each layer:

- **Personal**: an RA's `.do`-file convention library, Theorist's
  identification notes per paper, Referee's flag history.
- **Team**: the canonical estimator package (`reghdfe` v6.12.1), the
  canonical cluster level (prefecture-decade), the active submission queue,
  the open Referee flags per paper, the deadlines.
- **Project**: the research agenda, the canonical sample-frame rule, the
  archive lineage, the authorship-order policy, the IRB-authorization
  record per dataset, the citation style.

For full model, see sibling DESIGN.md §8.

---

## 9. Coordinator (lives inside PI)

The PI scores each task using the same LIGHT / MEDIUM / HEAVY scale as
`aiplus-auto-team-consultant`. Defaults in `econ-team.toml`:

| Tier | Complexity | Fires consultant | Typical staffing |
|---|---|---|---|
| LIGHT | ≤ 2 | No | Single RA, or single Writer pass |
| MEDIUM | 3-4 | Yes | RA + Theorist sign-off + Replicator |
| HEAVY | ≥ 5 OR risk ≥ 0.7 | Yes | Full team + relevant experts |

Research-specific scoring signals:

- **+1 complexity** if the task touches identification
- **+1 complexity** if the artifact is external-facing (submission, post)
- **+1 risk** if reversibility class is irreversible (submission, posting,
  authorship change)
- **+1 risk** if a deadline is binding and within 1 week
- **+1 complexity** if the task touches restricted / IRB data
- **+1 complexity** if the task changes the sample frame

PI auto-fires consultant on MEDIUM and HEAVY. PI never auto-fires
consultant on LIGHT (cost > value for trivial tasks).

---

## 10. Configuration Schema

All TOML files use `schema_version = "1.0"`. Per-role `.toml` schema:

```toml
schema_version = "1.0"

[agent]
role = "<slug>"
display_name = "<Display Name>"
tier = "owner_facing" | "internal_core" | "expert"
default_specialty = ""
warm_bench_ttl_seconds = 1800 | 3600

[persona]
system_prompt_file = "personas/<slug>.md"
voice = "<voice slug>"
escalation_target = "owner" | "pi"

[workspace]
needs_worktree = true | false
worktree_branch = "agent/<slug>"
worktree_path = "../{project_name}.<slug>"

[memory]
personal_dir = ".aiplus/agent-memory/<slug>"
read_team_memory = true
read_project_memory = true
write_team_memory = true | false

[invocation]
chinese_aliases = ["..."]
english_aliases = ["..."]
```

Team-wide `econ-team.toml` adds:

```toml
[team]
project_name = "<your-research-project>"
core_roles = [...]
active_experts = []
toolchain = ["python", "stata", "latex"]

[coordinator.light] / [coordinator.medium] / [coordinator.heavy]

[owner_interface]
default_visible = ["advisor", "pi"]
allow_direct_talk_to_others = true

[research_artifacts]
paper_dir = "paper/"
slides_dir = "slides/"
tables_dir = "output/tables/"
figures_dir = "output/figures/"
data_dir = "data/"
code_dir = "code/"
bib_file = "paper/references.bib"
```

---

## 11. CLI Surface

Mirrors agent-team's CLI exactly. All commands prefixed with
`aiplus agent`:

- `status` — show team roster, active experts, warm bench state, open
  flags, current submission queue
- `route <role|task-description>` — dispatch a task; PI scores and staffs
- `integrate <role>` — merge a role's branch back into main
- `audit run` — run acceptance audit per `.aiplus/agent-team/acceptance/v0.1.0/`
- `doctor` — validate configs, worktrees, memory layout
- `list` — list all roles (core + expert)
- `talk <role>` — direct conversation with one role (bypasses PI for
  read-only consultation; mutations still flow through PI)
- `invite <expert>` — summon an expert to the active team
- `dismiss <expert>` — remove an expert from the active team
- `transcript` — show recent activity for audit
- `prune-worktrees` — clean up stale worktrees

Research-specific extensions:

- `submission queue` — show paper / target / deadline / state per paper
- `flags open` — show open Referee + Replicator flags per artifact
- `replicate <artifact>` — kick off a Replicator pass on a named artifact

---

## 12. Integration with the Existing AiPlus Stack

```
                  aieconlab             ← orchestration layer
                           ↓ uses
               aiplus-auto-team-consultant           ← decision-support layer
                           ↓ uses
    AiPlus-Agent-Memory  AiPlus-Compact-Reminder  AiPlus-Agent-Velocity
               ←——————— shared infrastructure layer ———————→
```

- **aiplus-agent-memory** — each agent gets a namespaced memory under
  `.aiplus/agent-memory/<role>/`. Research adds new memory categories:
  identification notes, codebook history, falsification-test results.
- **AiPlus-Compact-Reminder** — saves tokens by triggering compact at the right moment and resuming cleanly. Each long-running agent (PI, Theorist,
  Writer) runs its own compact cycle. Compact preserves: open flags,
  active submission queue, identification notes, current spec sign-offs.
- **aiplus-agent-velocity** — each agent has its own velocity records,
  with research-specific units: regression-spec, table, figure,
  paper-section, referee-rebuttal, robustness-check, slide-deck,
  cleaning-pipeline-step.
- **aiplus-auto-team-consultant** — PI fires consultant before MEDIUM and
  HEAVY tasks; consultant findings flow into the staffed team's brief.

Coexistence with `aiplus-agent-team`: both can install into the same
project. Roles live in disjoint namespaces (`engineer-a` vs `ra-stata`).
Owner explicitly chooses which team to invoke per task. Useful for
researchers who maintain a replication-package repo alongside the paper
repo.

---

## 13. Owner Interaction Model

Default surface = Advisor + PI. The Owner does not see the internal team
unless they ask.

- Strategic question → Advisor → (returns recommendation) → Owner
- Execution task → PI → (scores, dispatches, integrates, reports) → Owner
- Status question → PI (always; the source of truth)
- Direct expert summon → Owner → PI (the PI logs and notifies)
- Inter-role conflict → PI mediates → escalates to Owner if unresolved in
  one round

The Owner can `talk <role>` for read-only consultation with any role —
useful for "ask Theorist directly what they think about the IV". Mutating
actions still flow through PI to keep the dispatch log clean.

---

## 14. Failure Modes & Fallbacks

| Failure | Detection | Fallback |
|---|---|---|
| Two RA branches touch the same file | git merge conflict on integrate | PI re-sequences; one RA waits for the other |
| Theorist sign-off missing on RA's spec | RA personal-memory check at dispatch | RA escalates before running |
| Replicator finds untraceable mismatch | precise diff in Replicator log | PI blocks ship; escalates to RA + Theorist |
| Referee flags major on external artifact | Referee report tagging | PI blocks ship; routes to Writer / Theorist |
| Restricted-data task without authorization | RA-Python authorization check | RA-Python refuses; routes to Owner via PI |
| Agent compact loses open flags | post-compact validation against team memory | Compact-reminder re-loads from team memory |
| Worktree state corrupt | `aiplus agent doctor` reports inconsistency | `aiplus agent prune-worktrees` rebuilds |
| Consultant unavailable on MEDIUM | timeout | PI proceeds with a flagged "no-consultant" dispatch and logs |

---

## 15. Privacy & Safety Boundaries

- **No upload.** No agent state, persona, memory, or transcript leaves
  the local machine. All agent traffic stays within the host runtime's
  existing network surface (Codex / Claude Code / OpenCode).
- **No daemon.** State-level permanence, not process-level. Agents are
  ephemeral processes spawned on demand.
- **No secrets in agent state.** Personas, memories, configs never store
  API keys, credentials, IRB-protected paths, restricted-archive paths.
- **Restricted data is per-task-authorized.** RA-Python refuses to touch
  `data/restricted/` without a per-task Owner-logged authorization record.
- **No global config edits.** The plugin does not modify ~/.codex,
  ~/.claude, or any global runtime config.
- **No cross-project bleed.** Each project's `.aiplus/` is self-contained.

---

## 16. STOP Gates

Actions that *always* escalate to the Owner; never auto-approved:

1. **Journal submission** (any tier).
2. **Working-paper posting** to NBER, SSRN, public preprint server.
3. **Sending a referee response** to the editor.
4. **Sharing data** with external parties (co-authors counted if not on
   the Owner-logged co-author list).
5. **Authorship-order change**.
6. **Acknowledgement / funding-attribution change** on any external artifact.
7. **Touching restricted data** without per-task authorization.
8. **Estimator change** that affects the headline result.
9. **Sample-frame change** that affects the headline result.
10. **Dropping a previously-reported robustness check.**
11. **Posting to social media** (X / Bluesky / blog) about the paper.
12. **Changing the submission target** (e.g. QJE → AER).

The PI prepares; the Owner approves.

---

## 17. MVP Roadmap

**v0.1.0 (this release):**
- All 8 core roles with full personas and TOML configs
- 8 of 11 experts shipped (full personas)
- 3 of 11 experts as config stubs (v0.2)
- Three adapters (codex, claude-code, opencode) with parity
- Examples per runtime
- Acceptance schema + audit tests

**v0.2.x:**
- Ship the 3 stub experts (Survey / Experiment, Computation, Co-Author Liaison)
- Velocity unit-type calibration from real-project history
- Per-paper memory partitions (one team can manage 3+ papers in parallel)

**v0.3.x:**
- Co-author Liaison full implementation
- Multi-project memory aggregation across the researcher's portfolio

---

## 18. Known Limitations

- **One project at a time.** v0.1 assumes one paper as the primary
  artifact. Researchers with three active papers will need to invoke the
  team per paper or use the project memory to disambiguate.
- **English + Chinese aliases only.** Other languages need persona +
  alias additions.
- **No structural model auto-scaffold.** A team that pivots to structural
  modeling needs the Owner to scope the structural section; the team will
  not propose structural pivots autonomously.
- **No grant / funding automation.** The team does not write grant
  applications, manage award statements, or track funding deadlines.
- **No teaching workflow.** Course prep, syllabus design, lecture notes
  are out of scope for v0.1.

---

## 19. Decisions

| Decision | Choice | Why |
|---|---|---|
| Rename CEO to PI | yes | Academic vocabulary; "CEO" is wrong register for a paper |
| Rename Architect to Theorist | yes | Identification + theory ≈ architecture for research |
| Rename Engineer A/B to RA-Stata/RA-Python | yes | Tool-explicit, matches how real teams talk |
| Rename Reviewer to Referee | yes | Vocabulary; "referee" is the journal term |
| Rename QA to Replicator | yes | Reproducibility is the QA equivalent for research |
| Default RA-Python dormant | yes | Many projects do not need Python data pipelines |
| Default toolchain Python + Stata + LaTeX | yes | Most-common applied econ stack |
| Sibling module, not profile of agent-team | yes | Roles, vocabulary, and STOP-gates differ enough to warrant separation; same architecture |
| Re-derive DESIGN sections 6/7/8 | no | Identical to sibling, cite |

---

## 20. Glossary

- **Owner**: the human user; the lead author of the research project.
- **Tier**: owner-facing / internal-core / expert.
- **STOP-gate**: an action the team never auto-approves.
- **Spec drift**: an RA's implementation drifting from Theorist's note.
- **Falsification test**: a Theorist-designed test that would refute the
  identification if it failed.
- **Clean-room rerun**: Replicator's reproduction from a fresh checkout.
- **Submission queue**: the list of active papers with target, deadline,
  state, and reversibility class.
- **External-facing artifact**: anything that leaves the team — submission,
  rebuttal, working-paper post, seminar deck, public talk slide.
- **Pre-review**: Referee's internal pass on an artifact before external
  ship.

---

## 21. Out of Scope for v0.1

- Teaching: syllabus design, lecture notes, exam authoring, TA management.
- Grant writing: NSF / NIH / private-foundation applications.
- Conference logistics: travel booking, expense management, panel
  organizing.
- Coauthor coordination beyond Co-Author Liaison (v0.2 stub).
- Author photo / professional website maintenance.
- Refereeing for journals (you-as-referee workflow): handled by sibling
  workflow in a future release.

---

## 22. Acceptance Criteria & Auditor

The acceptance schema at `.aiplus/aieconlab/acceptance/v0.1.0/schema.yaml`
is binding. Every release must pass:

1. All 8 core role `.toml` files load without TOML errors.
2. All 8 core role `personas/*.md` files exist and are non-empty.
3. All 11 expert `.toml` files exist (shipped or stub).
4. The `econ-team.toml` declares all 8 core roles.
5. The three adapters (codex, claude-code, opencode) have parity on the
   CLI surface declared in §11.
6. Every persona declares a forbidden-actions section.
7. Every persona's example section has ≥ 3 examples.
8. STOP-gates listed in §16 appear in PI and Replicator personas.
9. The doctor check on `aiplus-module.json` passes.
10. The acceptance audit `.test.sh` passes on a fresh clone.

Any behavioral change must update both the schema and its sibling
`.test.sh` before merge.

---

End of v0.1.0 design document.
