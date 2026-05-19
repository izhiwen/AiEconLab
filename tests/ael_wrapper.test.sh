#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash -n ael
bash -n scripts/build-ael.sh

version="$(./ael --version)"
[ "$version" = "AEL 0.2.0" ] || {
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
for cmd in update uninstall; do
  case "$help" in
    *"ael $cmd"*) ;;
    *)
      echo "::error::ael --help missing top-level command: $cmd"
      exit 1
      ;;
  esac
done

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

all_dry_run="$(./ael install all --dry-run)"
case "$all_dry_run" in
  *"runtime=all"*)
    echo "::error::ael install all --dry-run must not plan a literal all runtime"
    printf '%s\n' "$all_dry_run"
    exit 1
    ;;
esac
for runtime in codex claude-code opencode; do
  case "$all_dry_run" in
    *"runtime=$runtime"*) ;;
    *)
      echo "::error::ael install all --dry-run must mention runtime: $runtime"
      printf '%s\n' "$all_dry_run"
      exit 1
      ;;
  esac
  case "$all_dry_run" in
    *"would register the MCP server with $runtime"*) ;;
    *)
      echo "::error::ael install all --dry-run must mention MCP registration for runtime: $runtime"
      printf '%s\n' "$all_dry_run"
      exit 1
      ;;
  esac
done

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

grep -q "0.2.3" scripts/build-ael.sh || {
  echo "::error::build script missing v0.2.3 version anchor"
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

support_bin="$(mktemp)"
cat >"$support_bin" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$support_bin"

install_onboarding="$(AEL_AIPLUS_BIN="$support_bin" ./ael install codex)"
case "$install_onboarding" in
  *"Next: ael"*) ;;
  *)
    echo "::error::ael install must print Next: ael"
    printf '%s\n' "$install_onboarding"
    exit 1
    ;;
esac
case "$install_onboarding" in
  *"Quick start (your team is ready):"*) ;;
  *)
    echo "::error::ael install must print onboarding quick start"
    printf '%s\n' "$install_onboarding"
    exit 1
    ;;
esac
case "$install_onboarding" in
  *"ael advisor"*) ;;
  *)
    echo "::error::ael install onboarding must include advisor hint"
    printf '%s\n' "$install_onboarding"
    exit 1
    ;;
esac
case "$install_onboarding" in
  *"More: ael --help"*) ;;
  *)
    echo "::error::ael install onboarding must include help hint"
    printf '%s\n' "$install_onboarding"
    exit 1
    ;;
esac

install_suppressed="$(AEL_AIPLUS_BIN="$support_bin" AEL_NO_ONBOARDING=1 ./ael install codex)"
case "$install_suppressed" in
  *"Quick start (your team is ready):"*)
    echo "::error::AEL_NO_ONBOARDING=1 must suppress install onboarding"
    printf '%s\n' "$install_suppressed"
    exit 1
    ;;
esac

all_support="$(mktemp)"
all_support_log="$(mktemp)"
all_support_out="$(mktemp)"
cat >"$all_support" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$AEL_SUPPORT_LOG"
if [ "${1:-}" = "--help" ]; then
  printf 'Usage: ael-support\nCommands:\n  install\n  add\n  agent\n  mcp-register\n'
  exit 0
fi
if [ "${1:-}" = "install" ] && [ "${2:-}" = "opencode" ]; then
  printf 'opencode CLI not on PATH\n' >&2
  exit 42
fi
exit 0
SH
chmod +x "$all_support"
if AEL_AIPLUS_BIN="$all_support" AEL_SUPPORT_LOG="$all_support_log" ./ael install all >"$all_support_out" 2>&1; then
  echo "::error::ael install all must exit non-zero when one runtime fails"
  cat "$all_support_out"
  exit 1
fi
case "$(cat "$all_support_log")" in
  *"install all"*)
    echo "::error::ael install all must not pass literal all to the substrate"
    cat "$all_support_log"
    exit 1
    ;;
esac
for runtime in codex claude-code opencode; do
  case "$(cat "$all_support_log")" in
    *"install $runtime --allow-version-skew"*) ;;
    *)
      echo "::error::ael install all did not attempt runtime: $runtime"
      cat "$all_support_log"
      exit 1
      ;;
  esac
done
case "$(cat "$all_support_out")" in
  *"AEL install runtime=codex status=PASS"*\
*"AEL install runtime=claude-code status=PASS"*\
*"AEL install runtime=opencode status=FAIL"*\
*"AEL installed: codex ✓, claude-code ✓, opencode ✗ (CLI not on PATH)"*) ;;
  *)
    echo "::error::ael install all must print clear per-runtime status and final summary"
    cat "$all_support_out"
    exit 1
    ;;
esac

update_tmp="$(mktemp -d)"
update_release="$update_tmp/release"
update_pkg="$update_tmp/pkg/ael-v9.9.9-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
update_install="$update_tmp/install/bin"
update_libexec="$update_tmp/install/libexec"
mkdir -p "$update_release" "$update_pkg/bin" "$update_pkg/libexec" "$update_install" "$update_libexec"
cat >"$update_install/ael" <<'SH'
#!/usr/bin/env bash
printf 'AEL 0.2.0\n'
SH
cat >"$update_pkg/bin/ael" <<'SH'
#!/usr/bin/env bash
printf 'AEL 9.9.9\n'
SH
cat >"$update_pkg/libexec/ael-support" <<'SH'
#!/usr/bin/env bash
printf 'fake support\n'
SH
chmod +x "$update_install/ael" "$update_pkg/bin/ael" "$update_pkg/libexec/ael-support"
update_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
update_arch="$(uname -m)"
case "$update_arch" in
  arm64|aarch64) update_arch="aarch64" ;;
  x86_64|amd64) update_arch="x86_64" ;;
esac
update_asset="ael-v9.9.9-$update_os-$update_arch.tar.gz"
tar -C "$update_tmp/pkg" -czf "$update_release/$update_asset" "$(basename "$update_pkg")"
if command -v shasum >/dev/null 2>&1; then
  (cd "$update_release" && shasum -a 256 "$update_asset" > "$update_asset.sha256")
else
  (cd "$update_release" && sha256sum "$update_asset" > "$update_asset.sha256")
fi
update_project="$update_tmp/project"
mkdir -p "$update_project"
update_dry_run="$(
  cd "$update_project" && \
    AEL_INSTALL_DIR="$update_install" \
    AEL_LIBEXEC_DIR="$update_libexec" \
    AEL_UPDATE_LATEST_VERSION="v9.9.9" \
    AEL_BASE_URL="file://$update_release" \
    "$ael_abs" update --dry-run
)"
case "$update_dry_run" in
  *"AEL 0.2.0 → AEL 9.9.9"*) ;;
  *)
    echo "::error::ael update --dry-run must show version diff"
    printf '%s\n' "$update_dry_run"
    exit 1
    ;;
esac
case "$update_dry_run" in
  *"DRY_RUN=YES"*) ;;
  *)
    echo "::error::ael update --dry-run must report dry-run mode"
    printf '%s\n' "$update_dry_run"
    exit 1
    ;;
esac
case "$update_dry_run" in
  *"would_replace=$update_install/ael"*) ;;
  *)
    echo "::error::ael update --dry-run must show write targets"
    printf '%s\n' "$update_dry_run"
    exit 1
    ;;
esac
[ "$("$update_install/ael" --version)" = "AEL 0.2.0" ] || {
  echo "::error::ael update --dry-run must not replace installed wrapper"
  exit 1
}
[ ! -e "$update_libexec/ael-support" ] || {
  echo "::error::ael update --dry-run must not install support helper"
  exit 1
}
update_out="$(
  cd "$update_project" && \
    AEL_INSTALL_DIR="$update_install" \
    AEL_LIBEXEC_DIR="$update_libexec" \
    AEL_UPDATE_LATEST_VERSION="v9.9.9" \
    AEL_BASE_URL="file://$update_release" \
    "$ael_abs" update
)"
case "$update_out" in
  *"UPDATE_STATUS=PASS"*) ;;
  *)
    echo "::error::ael update must report pass after replacing files"
    printf '%s\n' "$update_out"
    exit 1
    ;;
esac
[ "$("$update_install/ael" --version)" = "AEL 9.9.9" ] || {
  echo "::error::ael update did not replace installed wrapper"
  exit 1
}
[ -x "$update_libexec/ael-support" ] || {
  echo "::error::ael update did not install support helper"
  exit 1
}
same_update="$(
  cd "$update_project" && \
    AEL_INSTALL_DIR="$update_install" \
    AEL_LIBEXEC_DIR="$update_libexec" \
    AEL_VERSION=9.9.9 \
    AEL_UPDATE_LATEST_VERSION="v9.9.9" \
    "$ael_abs" update --dry-run
)"
case "$same_update" in
  *"already up-to-date"*) ;;
  *)
    echo "::error::ael update must report already up-to-date when versions match"
    printf '%s\n' "$same_update"
    exit 1
    ;;
esac

uninstall_tmp="$(mktemp -d)"
uninstall_project="$uninstall_tmp/project"
uninstall_install="$uninstall_tmp/install/bin"
uninstall_libexec="$uninstall_tmp/install/libexec"
mkdir -p "$uninstall_project/.aiplus" "$uninstall_install" "$uninstall_libexec"
printf 'custom persona state\n' >"$uninstall_project/.aiplus/custom.txt"
printf 'fake ael\n' >"$uninstall_install/ael"
printf 'fake support\n' >"$uninstall_libexec/ael-support"
chmod +x "$uninstall_install/ael" "$uninstall_libexec/ael-support"
uninstall_out="$(
  cd "$uninstall_project" && \
    AEL_INSTALL_DIR="$uninstall_install" \
    AEL_LIBEXEC_DIR="$uninstall_libexec" \
    "$ael_abs" uninstall --yes
)"
case "$uninstall_out" in
  *"UNINSTALL_STATUS=PASS"*) ;;
  *)
    echo "::error::ael uninstall --yes must report pass"
    printf '%s\n' "$uninstall_out"
    exit 1
    ;;
esac
case "$uninstall_out" in
  *"preserved=$uninstall_project/.aiplus"*) ;;
  *)
    echo "::error::ael uninstall --yes must preserve project state by default"
    printf '%s\n' "$uninstall_out"
    exit 1
    ;;
esac
[ ! -e "$uninstall_install/ael" ] || {
  echo "::error::ael uninstall did not remove installed wrapper"
  exit 1
}
[ -e "$uninstall_project/.aiplus/custom.txt" ] || {
  echo "::error::ael uninstall without --purge removed project .aiplus"
  exit 1
}
purge_out="$(
  cd "$uninstall_project" && \
    AEL_INSTALL_DIR="$uninstall_install" \
    AEL_LIBEXEC_DIR="$uninstall_libexec" \
    "$ael_abs" uninstall --purge --yes
)"
case "$purge_out" in
  *"removed=$uninstall_project/.aiplus"*) ;;
  *)
    echo "::error::ael uninstall --purge --yes must remove current project .aiplus"
    printf '%s\n' "$purge_out"
    exit 1
    ;;
esac
case "$purge_out" in
  *"UNINSTALL_STATUS=PASS"*) ;;
  *)
    echo "::error::ael uninstall --purge --yes must report pass"
    printf '%s\n' "$purge_out"
    exit 1
    ;;
esac
[ ! -e "$uninstall_project/.aiplus" ] || {
  echo "::error::ael uninstall --purge left project .aiplus behind"
  exit 1
}

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
  *"Welcome to AEL"*) ;;
  *)
    echo "::error::first ael lobby run must print welcome"
    printf '%s\n' "$lobby_out"
    exit 1
    ;;
esac
[ -f "$lobby_dir/.aiplus/.ael-greeted" ] || {
  echo "::error::first ael lobby run must create greeted marker"
  exit 1
}
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
second_lobby_out="$(cd "$lobby_dir" && printf 'q\n' | "$ael_abs" 2>&1 || true)"
case "$second_lobby_out" in
  *"Welcome to AEL"*)
    echo "::error::subsequent ael lobby invocation must skip the welcome"
    printf '%s\n' "$second_lobby_out"
    exit 1
    ;;
esac
suppressed_lobby_dir="$(mktemp -d)"
mkdir -p "$suppressed_lobby_dir/.aiplus"
printf '{"runtimeAdapters":["codex"]}\n' >"$suppressed_lobby_dir/.aiplus/manifest.json"
suppressed_lobby_out="$(cd "$suppressed_lobby_dir" && printf 'q\n' | AEL_NO_ONBOARDING=1 "$ael_abs" 2>&1 || true)"
case "$suppressed_lobby_out" in
  *"Welcome to AEL"*)
    echo "::error::AEL_NO_ONBOARDING=1 must suppress first-run welcome"
    printf '%s\n' "$suppressed_lobby_out"
    exit 1
    ;;
esac
[ ! -e "$suppressed_lobby_dir/.aiplus/.ael-greeted" ] || {
  echo "::error::AEL_NO_ONBOARDING=1 should not create greeted marker"
  exit 1
}
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
