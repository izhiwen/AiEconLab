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
ael install
ael talk advisor "What is your role?"
```

The first command installs the `ael` CLI. Inside a paper or replication
project, `ael install` sets up the economics research team for your local AI
runtime. `ael talk advisor ...` opens a role-specific conversation.

## Demo

![AiEconLab demo](demo.gif)

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
IRB/sensitive-data review, visualization, computation, survey experiments, job
talks, and coauthor coordination.

## Install

Install the CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
```

If the installer says the target directory is not on `PATH`, add it:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then install AEL into a project:

```bash
cd MyPaperProject
ael install
```

By default AEL picks an available runtime in this order: Codex, Claude Code,
OpenCode. You can choose explicitly:

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

## Advanced

AEL is built on the AiPlus agent substrate; the supported user-facing product
surface is the `ael` CLI and this repository.

## License

Apache-2.0. See [LICENSE](LICENSE).
