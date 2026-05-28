# AiEconLab

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

[中文 README](README.zh-CN.md)

AiEconLab, or AEL, gives an economics paper project a small AI research team.
Instead of asking one chat to be your advisor, PI, RA, theorist, referee, and
replicator at the same time, you talk to the right role for the job.

Use AEL when you want help with:

- thinking through a research idea
- pressure-testing identification
- planning data work or regressions
- reviewing draft claims before they get too strong
- checking reproducibility and replication-package risk
- organizing the next steps in a paper project

## Start Here

1. Install one supported AI coding runtime first:
   [Claude Code](https://code.claude.com/docs/en/getting-started),
   [Codex](https://developers.openai.com/codex/cli), or
   [OpenCode](https://opencode.ai/docs/). Open it once by itself and make
   sure it works.
2. Install AEL with the command below.
3. Go to a paper, replication, or data project folder and run `ael`.
4. Pick who you want to talk to: PI, Advisor, RA-Stata, RA-Python, Referee, or
   another role.

The fastest start:

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
cd MyPaperProject
ael
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.ps1 | iex
cd MyPaperProject
ael install
ael
```

Windows support is currently CI-verified only. If you hit issues with the PowerShell quickstart, please open an issue at https://github.com/izhiwen/AiEconLab/issues — we'd like to hear about it.

On macOS/Linux, `ael` can set up the project on first run. On Windows, run
`ael install` once inside the project, then run `ael`.

If the installer says the command is not on `PATH`, use the one-line fix it
prints, then open a new terminal.

## What You Type

Open the lobby:

```bash
ael
```

Talk to the PI, who coordinates work:

```bash
ael pi
```

Ask the Advisor for a second opinion:

```bash
ael advisor
```

Go directly to a role when the task is clear:

```bash
ael ra-stata
ael ra-python
ael theorist
ael referee
ael replicator
ael pm
```

Start a fresh session instead of resuming the last one:

```bash
ael advisor --fresh
```

Check or repair the project setup:

```bash
ael status
ael doctor
ael doctor --fix
```

Refresh AEL-managed project files after an update:

```bash
ael refresh --dry-run
ael refresh
```

## Which Role Should I Pick?

Use **Advisor** when you want strategic judgment:

- Is this research question worth pursuing?
- Is the identification strategy credible?
- How ambitious is this realistically?
- What is the biggest referee risk?

Use **PI** when you want work organized:

- Break this into tasks.
- Decide who should do what.
- Check what is in flight.
- Turn Advisor feedback into concrete next steps.

Use **RA-Stata** for regressions, tables, Stata workflows, and robustness
checks.

Use **RA-Python** for cleaning, merging, scraping, GIS, text processing, and
Python pipelines.

Use **Theorist** for identification assumptions, mechanisms, models,
instruments, and interpretation.

Use **Referee** before you trust a claim. Referee reads like a skeptical
reviewer.

Use **Replicator** before numbers leave the project. Replicator checks whether
the result can be rerun cleanly.

Use **PM** for deadlines, blockers, milestones, and keeping the paper moving.

## Typical Workflows

Early idea:

```text
ael advisor
"I am thinking about a paper on X. What are the three biggest design risks?"
```

Turn a decision into work:

```text
ael pi
"Advisor thinks the main risk is topic selection. Plan the next validation step."
```

Before showing a result:

```text
ael referee
"Read this abstract and tell me the easiest reject reason."
```

Before relying on a table:

```text
ael replicator
"Check whether the main table can be reproduced from a clean checkout."
```

## What AEL Adds

AEL adds research roles and research discipline to an AI-assisted project:

- role-specific personas
- project-local memory
- team memory for shared decisions
- separate work boundaries for different roles
- economics-focused expert roles
- a research-tuned consultant team for medium and heavy tasks
- STOP-gates for actions that need the human Owner

It is not a promise that AI can run your research project alone. The human
researcher remains the Owner. AEL helps structure the work so the AI assistant
does not blur roles, overclaim results, or forget project context.

## Consultant Team

AEL has its own consultant team. It is not the default software-engineering
consultant team.

The AEL consultant team is built for economics research:

- design credibility
- contribution framing
- day-1 reproducibility
- IRB and disclosure risk
- LLM-as-measurement validity

Light tasks skip the consultant. Medium and heavy tasks can trigger it before
work is dispatched.

## LLM-as-Measurement

AEL includes an LLM-as-measurement specialist for projects that use language
models to score archival text, survey responses, open-ended documents, or other
unstructured sources.

The specialist focuses on validation: multi-model agreement, hand-coded labels,
inter-rater reliability, prompt-version stability, and measurement-error risk.

Companion example:
[Multi-LLM-Validation-Demo](https://github.com/izhiwen/Multi-LLM-Validation-Demo).

![Pairwise LLM correlation heatmap](https://raw.githubusercontent.com/izhiwen/Multi-LLM-Validation-Demo/main/figures/multi_llm_correlation_heatmap.png)

## Safety

AEL stays local to your project. It does not:

- upload project files, memory, or transcripts
- run as a background daemon
- store restricted-data paths or secrets in role personas
- modify unrelated projects
- auto-approve journal submissions, public paper posts, referee responses,
  data sharing, authorship changes, or other Owner-gated actions

Each role can help prepare work, but the human Owner decides when something
external, sensitive, or irreversible happens.

## Demo

The v1.0.0 readiness demo will link here when Lane B publishes the hosted
terminal recording.

## Troubleshooting

Check the project:

```bash
ael doctor
```

Let AEL fix common local drift:

```bash
ael doctor --fix
```

Preview an update:

```bash
ael update --dry-run
```

Remove the installed command, keeping project files:

```bash
ael uninstall --yes
```

Remove the installed command and this project's AEL state:

```bash
ael uninstall --purge --yes
```

## For Maintainers

Build a release package:

```bash
git submodule update --init --recursive
scripts/build-ael.sh --package
```

The release workflow publishes platform tarballs and SHA256 sidecars for the
installer.

## Advanced

AEL is built on the AiPlus agent substrate. The supported user-facing product
surface is the `ael` CLI and this repository.

## License

Apache-2.0. See [LICENSE](LICENSE).
