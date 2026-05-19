"""W8: persona behavior test runner.

For each persona × prompt pair in test_cases.toml:
  1. Load the persona body from core/templates/personas/<persona>.md
  2. Send an Anthropic API call: system = persona body, user = prompt
  3. Check the response against expects_any (must contain at least one)
     and forbids_any (must not contain any).
  4. Retry failed checks up to 3 attempts.
  5. Tally pass/fail per persona.

Exits non-zero if any persona's pass rate is below the threshold
(default 80%).

Designed to run from the AEL repo root in CI; can also be invoked
locally as `python tests/persona_behavior/test_persona_behavior.py`.

Environment:
  ANTHROPIC_API_KEY  required
  PERSONA_THRESHOLD  optional float in [0,1], default 0.80
  PERSONA_MODEL      optional, default "claude-haiku-4-5-20251001"
"""

from __future__ import annotations

import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore

try:
    from anthropic import Anthropic
except ImportError:
    Anthropic = None  # type: ignore[assignment]


REPO_ROOT = Path(__file__).resolve().parents[2]
PERSONAS_DIR = REPO_ROOT / "core" / "templates" / "personas"
CASES_FILE = Path(__file__).resolve().parent / "test_cases.toml"
MAX_ATTEMPTS = 3
RETRY_SLEEP_SECONDS = float(os.environ.get("PERSONA_RETRY_SLEEP_SECONDS", "5"))
MAX_WORKERS = int(os.environ.get("PERSONA_MAX_WORKERS", "2"))
SLOW_CALL_SECONDS = 30


def load_persona_body(persona_name: str) -> str:
    """Read the persona's full system prompt from disk.

    The persona file IS the system prompt — we send it verbatim. The
    AEL framing line under ## Role Identity carries the AiPlus
    backlink; the rest of the file enumerates Voice / Knowledge
    Boundaries / Escalation / Forbidden / Examples.
    """
    path = PERSONAS_DIR / f"{persona_name}.md"
    if not path.exists():
        raise FileNotFoundError(f"persona file missing: {path}")
    return path.read_text(encoding="utf-8")


def evaluate_response(
    response: str, expects_any: list[str], forbids_any: list[str]
) -> tuple[bool, str]:
    """Return (passed, reason). The first failing condition wins."""
    lo = response.lower()
    for bad in forbids_any:
        if bad.lower() in lo:
            return False, f"response contains forbidden substring '{bad}'"
    if expects_any:
        if not any(good.lower() in lo for good in expects_any):
            return (
                False,
                f"response missed all expected substrings: {expects_any!r}",
            )
    return True, "ok"


def response_head(response: str) -> str:
    return response.strip().splitlines()[0][:100] if response else "(empty)"


def create_message(
    client: Anthropic, model: str, system_prompt: str, prompt: str
) -> str:
    resp = client.messages.create(
        model=model,
        max_tokens=600,
        system=system_prompt,
        messages=[{"role": "user", "content": prompt}],
    )
    return "".join(block.text for block in resp.content if hasattr(block, "text"))


def run_case_with_retries(
    client: Anthropic,
    model: str,
    persona: str,
    kind: str,
    system_prompt: str,
    prompt: str,
    expects: list[str],
    forbids: list[str],
) -> dict[str, object]:
    """Run one stochastic persona assertion, retrying failed attempts."""
    last_reason = "not run"
    last_preview = "(empty)"

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response_text = create_message(client, model, system_prompt, prompt)
            ok, reason = evaluate_response(response_text, expects, forbids)
            preview = response_head(response_text)
            failure_kind = "assertion"
        except Exception as exc:  # noqa: BLE001
            ok = False
            reason = f"API_ERROR: {exc}"
            preview = "(api error)"
            failure_kind = "api"

        last_reason = reason
        last_preview = preview

        if ok:
            retries = attempt - 1
            marker = (
                "PASS"
                if retries == 0
                else f"PASS_AFTER_RETRY attempt={attempt} retries={retries}"
            )
            print(f"[{persona} {kind}] {marker} — {reason}")
            return {
                "ok": True,
                "attempts": attempt,
                "retries": retries,
                "reason": reason,
                "preview": preview,
            }

        if attempt < MAX_ATTEMPTS:
            print(
                f"::warning::[{persona} {kind}] attempt {attempt}/{MAX_ATTEMPTS} "
                f"failed ({failure_kind}) — retrying: {reason}"
            )
            print(f"  response head: {preview}")
            if RETRY_SLEEP_SECONDS > 0:
                time.sleep(RETRY_SLEEP_SECONDS)
            continue

    clean_or_api = (
        "API error" if last_reason.startswith("API_ERROR:") else "clean assertion failure"
    )
    print(
        f"[{persona} {kind}] FAIL_FINAL after {MAX_ATTEMPTS} attempts "
        f"({clean_or_api}) — {last_reason}"
    )
    print(f"  prompt: {prompt[:80]}")
    print(f"  response head: {last_preview}")
    return {
        "ok": False,
        "attempts": MAX_ATTEMPTS,
        "retries": MAX_ATTEMPTS - 1,
        "reason": last_reason,
        "preview": last_preview,
    }


def run_loaded_case(
    api_key: str,
    model: str,
    persona: str,
    case: dict,
    system_prompt: str,
) -> dict[str, object]:
    kind = case["kind"]
    client = Anthropic(api_key=api_key)
    result = run_case_with_retries(
        client,
        model,
        persona,
        kind,
        system_prompt,
        case["prompt"],
        case.get("expects_any", []),
        case.get("forbids_any", []),
    )
    result.update({"persona": persona, "kind": kind})
    return result


def append_step_summary(
    rows: list[dict[str, object]], model: str, threshold: float, overall_fail: bool
) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return

    total_retries = sum(int(row["retries"]) for row in rows)
    passed_after_retry = sum(
        1 for row in rows if bool(row["ok"]) and int(row["retries"]) > 0
    )
    status = "NEEDS_FIX" if overall_fail else "PASS"

    lines = [
        "## Persona behavior retry summary",
        "",
        f"- Status: `{status}`",
        f"- Model: `{model}`",
        f"- Threshold: `{threshold:.0%}`",
        f"- Total retries: `{total_retries}`",
        f"- Passed after retry: `{passed_after_retry}`",
        "",
        "| Persona | Case | Status | Attempts | Retries | Reason |",
        "| --- | --- | --- | ---: | ---: | --- |",
    ]
    for row in rows:
        reason = str(row["reason"]).replace("|", "\\|").replace("\n", " ")
        row_status = "PASS" if bool(row["ok"]) else "FAIL_FINAL"
        if bool(row["ok"]) and int(row["retries"]) > 0:
            row_status = f"PASS_AFTER_RETRY_N={row['attempts']}"
        lines.append(
            f"| {row['persona']} | {row['kind']} | {row_status} | "
            f"{row['attempts']} | {row['retries']} | {reason[:160]} |"
        )

    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("\n".join(lines))
        summary.write("\n")


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.stderr.write(
            "ANTHROPIC_API_KEY not set; W8 behavior tests cannot run.\n"
            "In CI this is the gate that skips the workflow on PRs from forks.\n"
        )
        return 0  # Skip, don't fail.

    if Anthropic is None:
        sys.stderr.write(
            "anthropic package missing. install with: pip install anthropic tomli\n"
        )
        return 2

    threshold = float(os.environ.get("PERSONA_THRESHOLD", "0.80"))
    model = os.environ.get("PERSONA_MODEL", "claude-haiku-4-5-20251001")

    cases_doc = tomllib.loads(CASES_FILE.read_text(encoding="utf-8"))
    cases = cases_doc.get("cases", [])
    if not cases:
        sys.stderr.write("no cases in test_cases.toml; nothing to do\n")
        return 1

    # Group by persona for pass-rate accounting.
    by_persona: dict[str, list[dict]] = {}
    for case in cases:
        by_persona.setdefault(case["persona"], []).append(case)

    overall_fail = False
    summary_rows: list[dict[str, object]] = []
    print(f"W8 persona behavior: {len(cases)} cases across {len(by_persona)} personas")
    print(f"model={model} threshold={threshold:.0%}")
    worker_count = max(1, min(MAX_WORKERS, len(cases)))
    estimated_worst_seconds = (
        ((len(cases) + worker_count - 1) // worker_count)
        * MAX_ATTEMPTS
        * SLOW_CALL_SECONDS
    )
    print(
        f"retry_attempts={MAX_ATTEMPTS} max_workers={worker_count} "
        f"estimated_worst_case={estimated_worst_seconds // 60}m{estimated_worst_seconds % 60}s"
    )
    print("-" * 72)

    runnable_cases: list[tuple[str, dict, str]] = []
    for persona, persona_cases in sorted(by_persona.items()):
        try:
            system_prompt = load_persona_body(persona)
        except FileNotFoundError as e:
            print(f"[{persona}] PERSONA_MISSING — {e}")
            overall_fail = True
            for case in persona_cases:
                summary_rows.append(
                    {
                        "persona": persona,
                        "kind": case["kind"],
                        "ok": False,
                        "attempts": 0,
                        "retries": 0,
                        "reason": f"PERSONA_MISSING: {e}",
                    }
                )
            continue
        for case in persona_cases:
            runnable_cases.append((persona, case, system_prompt))

    if runnable_cases:
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            futures = [
                executor.submit(
                    run_loaded_case, api_key, model, persona, case, system_prompt
                )
                for persona, case, system_prompt in runnable_cases
            ]
            for future in as_completed(futures):
                summary_rows.append(future.result())

    print("-" * 72)
    for persona, persona_cases in sorted(by_persona.items()):
        persona_rows = [row for row in summary_rows if row["persona"] == persona]
        if not persona_rows:
            continue

        passed = sum(1 for row in persona_rows if bool(row["ok"]))
        rate = passed / len(persona_cases)
        rate_marker = "OK" if rate >= threshold else "FLAKY"
        print(
            f"  persona summary: {persona} {passed}/{len(persona_cases)} "
            f"({rate:.0%}) {rate_marker}"
        )
        if rate < threshold:
            overall_fail = True

    print("-" * 72)
    print("W8_PERSONA_BEHAVIOR_STATUS=" + ("NEEDS_FIX" if overall_fail else "PASS"))
    append_step_summary(summary_rows, model, threshold, overall_fail)
    return 1 if overall_fail else 0


if __name__ == "__main__":
    sys.exit(main())
