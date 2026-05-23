# AEL CLI quick reference

**This file is read by personas (PI, Advisor) when the Owner asks how
to use the AEL CLI itself.** It is the single source of truth for
user-facing `ael` commands. Adding a new command? Update this file
once and every persona automatically learns it.

## Entry — how to start a session

| Owner says... | Persona answers with... |
|---|---|
| "How do I open AEL?" / "How do I start?" | `ael` (auto-sets-up the team on first run, then opens the lobby — pick PI, Advisor, writer, etc.; if multiple runtimes are installed, choose one when prompted) |
| "I want to talk to PI directly" | `ael pi` |
| "I want to talk to Advisor directly" | `ael advisor` |
| "I want to talk to a writer / RA / referee / etc. directly" | `ael writer` / `ael ra-stata` / `ael ra-python` / `ael theorist` / `ael referee` / `ael replicator` / `ael pm` (one of 9 core roles) |
| "I want to see the lobby again" | `ael chat` |

## Setup — first time on a machine / project

| Owner says... | Persona answers with... |
|---|---|
| "How do I install AEL on a new machine?" | `curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh \| bash` |
| "I installed but `ael` is not found" | `curl ... \| bash` again with `--add-to-path` flag, OR add `~/.local/bin` to PATH manually |
| "How do I set up AEL in this paper project?" | `cd MyPaperProject && ael` |
| "How do I refresh a specific runtime adapter?" | `cd MyPaperProject && ael install codex` / `ael install claude-code` / `ael install opencode` |
| "How do I set up every supported runtime in this project manually?" | `cd MyPaperProject && ael install all` (installs codex, claude-code, and opencode in sequence; the final summary shows which runtimes succeeded) |

## Day-to-day — once you are running

| Owner says... | Persona answers with... |
|---|---|
| "What is installed in this project?" | `ael status` |
| "Something feels broken / I see NEEDS_FIX" | `ael doctor --fix` |
| "Is there a newer version of AEL?" | `ael update --dry-run` (shows what would change) then `ael update` to apply |
| "I don't want AEL anymore" | `ael uninstall --yes` (removes wrapper) OR `ael uninstall --purge --yes` (also removes project team config) |

## Safety / bypass

| Owner says... | Persona answers with... |
|---|---|
| "How do I turn off automatic runtime bypass?" | AEL removed `AEL_BYPASS` in v0.3.0. Use your runtime's normal safe-mode / approval setting before launching `ael`. |

## How personas should use this reference

When the Owner asks any question matching the left column above:

1. **Read this file** from `.aiplus/modules/aieconlab/core/templates/ael-cli-reference.md` (relative to the project root, which is your current working directory).
2. **Quote the exact command** from the right column verbatim — do NOT paraphrase or guess. Don't construct commands that aren't in this list.
3. **Never auto-run** these commands. Always tell the Owner what to type — these are Owner-controlled actions.
4. If the Owner's question doesn't match any entry, say so honestly and suggest they run `ael --help` themselves to see the full surface.

## Anti-patterns (don't do these)

- ❌ Don't make up commands like `ael upgrade` or `ael remove` — only the commands in this file exist.
- ❌ Don't say `aiplus <something>` to the Owner — that is the substrate, not AEL. Users should never see it.
- ❌ Don't auto-execute these commands "to be helpful". The Owner is the only one who runs them.
- ❌ Don't memorize this list across sessions — re-read it each time, since new versions of AEL add commands here.

## Source

This file lives at `core/templates/ael-cli-reference.md` in the AEL
repo. The `scripts/build-ael.sh` rsync ships it to
`assets/aieconlab/core/templates/` in the aiplus binary embed, which
extracts to `.aiplus/modules/aieconlab/core/templates/` during `aiplus add aieconlab`.

Updates to the AEL CLI must update this file in the same PR.
