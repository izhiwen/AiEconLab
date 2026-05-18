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

# `ael --help` must list all 9 core roles as direct-shortcut commands.
help_out="$(./ael --help)"
for role in pi advisor writer ra-stata ra-python theorist referee replicator pm; do
  case "$help_out" in
    *"ael $role"*) ;;
    *)
      echo "::error::ael --help missing direct-shortcut entry for role: $role"
      exit 1
      ;;
  esac
done
case "$help_out" in
  *"opens the lobby"*) ;;
  *)
    echo "::error::ael --help must mention the lobby as the no-arg behavior"
    exit 1
    ;;
esac

# Lobby behavior: when `ael` runs in a project that DOES have a manifest,
# stdin closed should print the team menu (then fail to read) without
# crashing or leaking substrate branding. The empty-stdin case lets us
# verify the menu surface without actually exec'ing the substrate.
lobby_dir="$(mktemp -d)"
mkdir -p "$lobby_dir/.aiplus"
printf '{"runtimeAdapters":["codex"]}\n' >"$lobby_dir/.aiplus/manifest.json"
lobby_out="$(cd "$lobby_dir" && "$ael_abs" < /dev/null 2>&1 || true)"
case "$lobby_out" in
  *AiPlus*|*aiplus*|*AIPLUS*)
    # Filter out the legitimate .aiplus/manifest.json path — it's a real
    # path on disk and shows up in error output, but it's not user-facing
    # branding. Only the wrapper's own text matters.
    filtered="$(printf '%s' "$lobby_out" | grep -vE '\.aiplus/|vendor/aiplus|/aiplus')"
    case "$filtered" in
      *AiPlus*|*aiplus*|*AIPLUS*)
        echo "::error::ael lobby leaks substrate branding (outside known path strings)"
        printf '%s\n' "$lobby_out"
        exit 1
        ;;
    esac
    ;;
esac
case "$lobby_out" in
  *"Core team"*) ;;
  *)
    echo "::error::ael lobby must print the team menu"
    printf '%s\n' "$lobby_out"
    exit 1
    ;;
esac
for role_kw in "pi" "advisor" "writer" "ra-stata" "ra-python" "theorist" "referee" "replicator" "pm"; do
  case "$lobby_out" in
    *"$role_kw"*) ;;
    *)
      echo "::error::ael lobby menu missing role: $role_kw"
      printf '%s\n' "$lobby_out"
      exit 1
      ;;
  esac
done

echo "AEL_WRAPPER_TEST=PASS"
