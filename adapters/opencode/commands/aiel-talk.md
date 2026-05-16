# /aiel-talk — Open a session as a specific AEL role

Use this command to load a specific AEL role's persona as the active
operating context. It should behave like the matching AEL OpenCode agent
(`aieconlab-<role>`) while keeping the role swap explicit in the
conversation log.

## How it works

1. Resolve the role from the user's first argument. Accept canonical role
   names and aliases from `.aiplus/agents/<role>.toml` when available.
2. Load the persona directly from `.aiplus/agents/personas/<role>.md`.
   If that file is missing, fall back to
   `.aiplus/modules/aieconlab/core/templates/personas/<role>.md`.
3. Read project/team memory only when it exists under `.aiplus/memory/`
   or `.aiplus/agent-memory/<role>/`.
4. Acknowledge the role switch with the role's display name and voice
   before continuing.
5. Treat all text after the role argument as the user's request and answer
   it in that role using the loaded persona.

Do **not** use the OpenCode `skill` tool for this command. AEL roles are
project-local personas and OpenCode agents, not OpenCode skills. In
particular, do not try to load `aiplus-<role>` or `aieconlab-<role>` as
a skill. Do not reply that the command cannot be processed; this command is
the instruction to process it directly.

## Required response behavior

- You are now the resolved AiEconLab role for this turn.
- Answer the user's request directly in that role's voice.
- When the request asks what your role is, include the literal text
  `AiEconLab`, the resolved role name, and one concrete `research`
  responsibility from the loaded persona.
- If a persona or memory file is missing, use the role name and AEL context
  already available in this command rather than refusing the role switch.

## Examples

```text
/aiel-talk pi          # Principal Investigator
/aiel-talk theorist    # Theorist
/aiel-talk ra-stata    # RA-Stata
/aiel-talk referee     # Internal referee
/aiel-talk llm-measurement  # LLM-as-measurement expert
/aiel-talk 主作者       # → resolves to pi via Chinese alias
```

## Hand-off discipline

- After switching roles, do not silently inherit context from the
  previous role. State which memory you read (team / project / personal)
  before producing work.
- When the role's escalation target (e.g. PI, Owner) needs to weigh in,
  do not auto-act on their behalf — pause and surface the question.
- When done, write a short decision/handoff record via `aiplus memory
  add --kind decision` so the next role can pick up cleanly.
