#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash -n ael
bash -n scripts/build-ael.sh

version="$(./ael --version)"
[ "$version" = "AEL 0.1.5" ] || {
  echo "::error::unexpected ael version output: $version"
  exit 1
}

help="$(./ael --help)"
case "$help" in
  *AiPlus*|*aiplus*|*AIPLUS*)
    echo "::error::ael help leaks substrate branding"
    exit 1
    ;;
esac

dry_run="$(./ael install codex --dry-run)"
case "$dry_run" in
  *AiPlus*|*aiplus*|*AIPLUS*|*.AEL*)
    echo "::error::ael install dry-run leaks or corrupts substrate details"
    printf '%s\n' "$dry_run"
    exit 1
    ;;
esac
case "$dry_run" in
  *"would register the MCP server"*) ;;
  *)
    echo "::error::ael install dry-run must mention MCP registration step"
    printf '%s\n' "$dry_run"
    exit 1
    ;;
esac

fake_bin="$(mktemp -d)"
cat >"$fake_bin/codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
answer_file=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output-last-message)
      answer_file="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "$answer_file" ] || exit 2
printf 'AiPlus leak via headless aiplus AIPLUS\n' >"$answer_file"
printf 'noisy AiPlus session log\n'
SH
chmod +x "$fake_bin/codex"
talk_output="$(PATH="$fake_bin:$PATH" ./ael talk --runtime codex advisor "What is your role?")"
case "$talk_output" in
  *AiPlus*|*aiplus*|*AIPLUS*)
    echo "::error::ael talk output leaks substrate branding"
    printf '%s\n' "$talk_output"
    exit 1
    ;;
esac

grep -q "vendor/aiplus/target/release" ael || {
  echo "::error::ael wrapper does not dispatch to vendored runtime"
  exit 1
}

grep -q "0.1.5" scripts/build-ael.sh || {
  echo "::error::build script missing v0.1.5 version anchor"
  exit 1
}

# `ael` with no args in a non-installed project must emit a friendly hint
# (not a stack trace, not substrate leak) and exit non-zero. The check uses
# a fresh empty tempdir as CWD so .aiplus/manifest.json is guaranteed absent.
no_args_dir="$(mktemp -d)"
no_args_stderr="$(mktemp)"
ael_abs="$(cd "$(dirname "$0")/.." && pwd)/ael"
if ( cd "$no_args_dir" && "$ael_abs" ) >/dev/null 2>"$no_args_stderr"; then
  echo "::error::ael with no args in an empty project should fail (no manifest)"
  exit 1
fi
case "$(cat "$no_args_stderr")" in
  *"ael install"*) ;;
  *)
    echo "::error::ael no-args hint must point user to 'ael install'"
    cat "$no_args_stderr"
    exit 1
    ;;
esac
case "$(cat "$no_args_stderr")" in
  *AiPlus*|*aiplus*|*AIPLUS*)
    echo "::error::ael no-args hint leaks substrate branding"
    cat "$no_args_stderr"
    exit 1
    ;;
esac

echo "AEL_WRAPPER_TEST=PASS"
