# AiEconLab

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

[中文 README](README.zh-CN.md)

AiEconLab gives AI-assisted economics projects a research-team structure.
Instead of asking one chat to be PI, RA, theorist, referee, and replicator at
once, AEL gives each role a separate persona, workspace boundary, and set of
responsibilities.

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
cd MyPaperProject
ael                              # auto-sets-up the team, then opens the lobby
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.ps1 | iex
cd MyPaperProject
ael install
ael
```

The first command installs the `ael` CLI. Inside a paper or replication
project, just running `ael` sets up adapters for supported runtimes on
`PATH`, opens the lobby, and asks who you want to talk to. If more than one
runtime is installed, AEL also asks which runtime to use.

## I'm New — Start Here

If you've never used Claude Code, Codex, or OpenCode before, do these
three things first (in this order). It'll save you an hour.

### Step 1: Install ONE AI coding agent first

Pick ONE to start (you can add more later):

- **Claude Code** (recommended for most researchers) — install from
  [claude.com/download](https://claude.com/download). Comes with
  Claude Pro; no separate API key needed.
- **Codex** — OpenAI's CLI. Requires a paid OpenAI account.
- **OpenCode** — open source, runs local or remote models.

Confirm the agent works on its own first (open it, ask "hi") before
adding AEL on top.

### Step 2: Install AEL

Open the macOS Terminal app, paste this **one line**, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
```

On Windows, open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.ps1 | iex
```

If it says "command not added to PATH," follow the one-line fix it
prints. This is a one-time setup per machine.

### Step 3: Try it in a paper project

Make a folder for a paper (or use an existing one), then:

```bash
cd MyPaperProject       # the folder where your paper lives
ael                     # auto-sets-up the team, then opens the lobby
```

Pick PI to start with your project manager, or pick Advisor / writer / RA
directly. Tell it what you want:
"I'm starting a paper on X, what should I think about first?" → PI hands
it to Advisor. "Draft an introduction for the identification strategy" →
PI dispatches to Writer. You stay in one window; PI orchestrates.

### Common first-day questions

- **"Do I need an API key?"** Not if you already have Claude Pro or
  ChatGPT Plus desktop. Only needed for batch / unattended runs.
- **"Will it touch my real paper files?"** No — read-only by default.
  Each role gets its own isolated workspace under the project's hidden
  team directory.
- **"How do I undo the install?"** Run `ael uninstall --yes`; add `--purge`
  inside one project to also remove that project's hidden team state.
- **"Is my data uploaded anywhere?"** No. All local. Roles log inside
  your project, never to a server.
- **"It says `NEEDS_FIX` — what now?"** Run `ael doctor --fix`. The
  most common fix is rerunning `ael install` to refresh the adapter.
  If you're still stuck, open a GitHub issue with the doctor output.

---

## Demo

<!-- demo recording temporarily removed from the repo to keep clone size small.
     Replacement: a hosted short-form recording (asciinema / loom) is planned
     for v0.2.x. -->
*(demo recording — coming back as a hosted asset in a future release)*

## What AEL Adds

AEL is built for applied economists who use AI assistants across long paper
projects: data cleaning, Stata regressions, Python merges, identification
debates, literature positioning, seminar revisions, replication packages, and
referee responses.

It gives you:

- **Advisor** for strategic second opinions on framing, identification risk,
  and publication tradeoffs.
- **PI** for scoping tasks, dispatching roles, integrating results, and keeping
  the project coherent.
- **Theorist** for identification strategy, mechanisms, instruments, and model
  logic.
- **RA-Stata** for Stata analysis, regression tables, robustness checks, and
  reproducible `.do` workflows.
- **RA-Python** for data cleaning, scraping, matching, GIS, and Python
  pipelines.
- **Referee** for pre-submission critique before a draft leaves the team.
- **Replicator** for clean-room reruns and replication-package failures.
- **PM** for deadlines, scope, blockers, and milestone discipline.

There are also specialist roles for literature review, writing, econometrics,
LLM-as-measurement validation, reproducibility engineering, historical sources,
IRB/sensitive-data review, visualization, computation, survey experiments,
degrees-of-freedom auditing, R&R strategy, job talks, and coauthor coordination.

## How the Team Works in Your Runtime

- **Switch roles in plain language.** Mid-session, say "you are PI",
  "take the referee role", or "switch to RA-Stata" and the agent
  responds as that role, with that role's research memory loaded.
  No CLI command. Works in Codex, Claude Code, and OpenCode
  interactive mode.

- **Intent-aware guardrails when PI delegates.** Before PI hands
  off anything risky to an RA — deleting files, modifying live
  data, publishing changes — the coordinator understands what
  you're actually asking for, not just the words you typed.
  Rephrasing or putting things in quotes can't slip a destructive
  command through. Especially useful when replication scripts
  touch shared archives or paper drafts.

- **Parallel review and QA for fast PI → RA → Referee cycles.**
  Review and QA steps run side by side, and each role's workspace
  stays warm between tasks. A typical robustness-table iteration
  lands in ~8-10 min instead of ~15-20, same quality bar. AEL
  inherits this from the underlying AiPlus.

## Install

Install the CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.ps1 | iex
```

If the installer says the target directory is not on `PATH`, add it:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

On Windows, the installer prints a one-line PowerShell command when
the install directory is not on `PATH`.

Then start AEL inside a project:

```bash
cd MyPaperProject
ael
```

On first run, AEL installs adapters for the supported runtime CLIs it finds
on `PATH` (Codex, Claude Code, OpenCode). If it finds one runtime, it uses
that runtime. If it finds more than one, the lobby asks you to choose.

You can still set up or refresh a runtime explicitly:

```bash
ael install codex
ael install claude-code
ael install opencode
```

Verify the project setup:

```bash
ael status
ael doctor
```

## Daily Use

Talk to the Advisor:

```bash
ael talk advisor "Is this identification strategy credible enough for a top-field submission?"
```

Route work through the PI:

```bash
ael route pi "scope the next robustness table and dispatch the right RA"
```

Talk to implementation roles when the task is already clear:

```bash
ael talk ra-stata "Sketch the Stata plan for the main IV table."
ael talk ra-python "Plan the merge checks for the county-level panel."
ael talk referee "Give me the harsh pre-submission read of this abstract."
```

Bring in an expert:

```bash
ael invite llm-measurement
ael talk llm-measurement "Review my text-as-data validation plan."
```

Note: `AEL_BYPASS` was removed in v0.3.0; use your normal safe-mode runtime
settings when you want approval prompts.

## Common Research Workflows

These examples show how to combine AEL roles across the life of a paper. Each
transcript is illustrative: replace the topic, data, journal, and table names
with your own project details.

### A. Idea Exploration

Use this when the project is still just a hunch. Start with Advisor for taste
and tradeoffs, then move to Theorist when you want the identification logic
made precise.

```bash
cd ~/research/early-idea
ael
> I have a possible paper idea about transit access and local labor markets.
> Help me think through whether there is a credible causal design.
> Switch to theorist and pressure-test the assumptions.
> Summarize the two most promising designs and the fatal threats.
```

### B. Literature Mapping

Use PI to scope the literature review, invite a specialist if needed, and then
ask Writer to turn the map into prose once the buckets are clear.

```bash
cd ~/research/transit-paper
ael pi
> Scope a literature map for transit access, commuting, and neighborhood change.
> Bring in a literature reviewer if this needs specialist coverage.
ael writer
> Turn the literature map into a second intro paragraph with a clear gap.
```

### C. Theory Building

Use this when the empirical idea is plausible but the exclusion restriction,
timing, or equilibrium story still needs discipline.

```bash
cd ~/research/instrument-paper
ael theorist
> I want to use distance to a historical rail junction as an instrument.
> Spell out the exclusion restriction and likely violation channels.
ael ra-stata
> Plan the first-stage F-stat and balance checks.
ael advisor
> Would this identification story survive a top-field seminar?
```

### D. Data Pipeline

Use PI to assign the pipeline, RA-Python to clean and merge, and RA-Stata to
verify the analysis-ready dataset before regressions start.

```bash
cd ~/research/panel-build
ael pi
> Send RA-Python a task: merge the county panel and produce Stata-ready output.
ael ra-python
> Build the merge checks and write the cleaned panel.
ael ra-stata
> Open the cleaned data and report summary statistics plus missingness.
```

### E. Implementation Chain

Use this for the main empirical workflow: think with Advisor, dispatch through
PI, execute with the RA, and let Referee challenge the result.

```bash
cd ~/research/rd-paper
ael
> I want to reflect on the RD design around the eligibility cutoff.
ael pi
> Dispatch RD bandwidth sensitivity to RA-Stata.
ael ra-stata
> Run the assigned bandwidth sensitivity table.
ael referee
> Review the table as if it were in the first submission.
```

### F. Robustness Sprint

Use this when the main result exists and you need a compact sprint of
alternative specifications before deciding what becomes main or appendix.

```bash
cd ~/research/main-table
ael pi
> Plan five robustness specs: bandwidth, outliers, clustering, window, sample.
ael ra-stata
> Run the five specs and label which result maps to which threat.
ael referee
> Rank the specs: main table, appendix, or unnecessary.
```

### G. Writing Review Loop

Use Writer for actual drafting and Advisor for strategic critique. Keep the
loop tight: draft, critique, revise, then move on.

```bash
cd ~/research/draft
ael writer
> Draft the first intro paragraph around the core contribution.
> Add a second paragraph on the literature gap.
ael advisor
> Is the intro strong, specific, and honest about identification?
ael writer
> Revise the opening using the Advisor's critique.
```

### H. Pre-Submission Scrub

Use this before sending a paper anywhere. Referee finds the hard objections,
PI coordinates a degrees-of-freedom audit, and Writer integrates the changes.

```bash
cd ~/research/submission
ael referee
> Do an internal review for a submission to Journal X.
ael pi
> Bring in a degrees-of-freedom audit and summarize the required fixes.
ael writer
> Revise the robustness section around the referee and audit notes.
```

### I. R&R Response

Use PI to turn referee reports into a work plan, RA-Stata for new requested
analyses, and Writer for the response letter.

```bash
cd ~/research/revision
ael pi
> Triage this referee report and prioritize the response plan.
ael ra-stata
> Run the requested heterogeneity and falsification tests.
ael writer
> Draft the response letter point by point, linking claims to new results.
```

### J. Clean-Room Replication

Use Replicator when you want a result checked without inheriting the original
author's code path or your own builder assumptions.

```bash
cd ~/research/replication
ael replicator
> Reproduce Table 3 from the paper text without reading the original code.
ael ra-stata
> Implement the Table 3 RD specification with independently chosen bandwidth.
ael replicator
> Compare our result with Table 3 and explain any discrepancy.
```

## Why Roles Matter

One long-lived AI chat tends to blur responsibilities. The same assistant that
debugged a Stata loop starts drafting prose with code-shaped habits. The same
assistant that helped frame the intro becomes too invested to act like a
skeptical referee.

AEL keeps those jobs separate:

- RA memories stay focused on data, variables, and code decisions.
- Theorist and Referee critiques do not get diluted by execution context.
- PI owns integration instead of letting parallel work collide silently.
- Replicator gets a clean-room mandate rather than sharing the builder's
  assumptions.

The result is not "more agents" for its own sake. It is a project structure
that matches how serious research teams already work.

## LLM-as-Measurement

AEL includes an LLM-as-measurement specialist for projects that use language
models to score archival text, survey responses, open-ended documents, or other
unstructured sources. This role focuses on validation design: multi-model
agreement, held-out human labels, inter-rater statistics, prompt-version
stability, and measurement-error implications for the empirical result.

Companion example:
[Multi-LLM-Validation-Demo](https://github.com/izhiwen/Multi-LLM-Validation-Demo).

![Pairwise LLM correlation heatmap (294 archival docs × 5 frontier LLMs, mean ρ ≈ 0.92)](https://raw.githubusercontent.com/izhiwen/Multi-LLM-Validation-Demo/main/figures/multi_llm_correlation_heatmap.png)

## Safety

AEL stays local to your project. It does not:

- upload project files, memory, or transcripts
- run as a background daemon
- store restricted-data paths or secrets in role personas
- modify unrelated projects
- auto-approve Owner-gated actions such as journal submission, public posting,
  referee-response sending, data sharing, or authorship changes

The CLI installs project files under local project state and uses your selected
runtime to answer as the requested role.

## Release Build

For maintainers:

```bash
git submodule update --init --recursive
scripts/build-ael.sh --package
```

The release workflow publishes platform tarballs and SHA256 sidecars for the
installer.

## Development

### Automated AiPlus version tracking

A daily GitHub Action watches the AiPlus upstream repo for new stable tags and
automatically opens a PR to bump the vendored substrate. Human review is
required before merge; auto-bump never merges itself.

## Advanced

AEL is built on the AiPlus agent substrate; the supported user-facing product
surface is the `ael` CLI and this repository.

## License

Apache-2.0. See [LICENSE](LICENSE).
