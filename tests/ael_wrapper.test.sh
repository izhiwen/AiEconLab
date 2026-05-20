#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
ael_abs="$repo_root/ael"

fail() {
  echo "::error::$*" >&2
  exit 1
}

make_project() {
  local project
  project="$(mktemp -d)"
  mkdir -p "$project/.aiplus/agents/personas"
  printf '{"runtimeAdapters":["codex"],"modules":{"aieconlab":{"version":"test"}}}\n' \
    >"$project/.aiplus/manifest.json"
  local role
  for role in pi advisor writer ra-stata ra-python theorist referee replicator pm; do
    printf '# %s\n' "$role" >"$project/.aiplus/agents/personas/$role.md"
  done
  printf '%s\n' "$project"
}

bash -n ael
bash -n scripts/build-ael.sh

version="$(./ael --version)"
[ "$version" = "AEL 0.2.10" ] || fail "unexpected ael version output: $version"

help="$(./ael --help)"
for cmd in "ael install" "ael update" "ael uninstall" "ael doctor" "ael status"; do
  case "$help" in
    *"$cmd"*) ;;
    *) fail "ael --help missing AEL-specific command: $cmd" ;;
  esac
done
for role in pi advisor writer ra-stata ra-python theorist referee replicator pm; do
  case "$help" in
    *"ael $role"*) ;;
    *) fail "ael --help missing direct-shortcut entry for role: $role" ;;
  esac
done

delegate_bin="$(mktemp -d)"
cat >"$delegate_bin/aiplus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  printf 'aiplus 0.6.16\n'
  exit 0
fi
printf 'AIPLUS_BRAND=%s\n' "${AIPLUS_BRAND:-}"
printf 'AIPLUS_TEAM=%s\n' "${AIPLUS_TEAM:-}"
printf 'AIPLUS_DEFAULT_ROLE=%s\n' "${AIPLUS_DEFAULT_ROLE:-}"
printf 'ARGS=%s\n' "$*"
SH
chmod +x "$delegate_bin/aiplus"

assert_delegate() {
  local expected_args="$1"
  shift
  local project out
  project="$(make_project)"
  out="$(cd "$project" && PATH="$delegate_bin:$PATH" "$ael_abs" "$@")"
  case "$out" in
    *"AIPLUS_BRAND=AEL"*\
*"AIPLUS_TEAM=aieconlab"*\
*"AIPLUS_DEFAULT_ROLE=pi"*\
*"ARGS=$expected_args"*) ;;
    *)
      printf '%s\n' "$out"
      fail "unexpected delegate output for ael $*"
      ;;
  esac
}

assert_delegate ""
assert_delegate "agent talk advisor" advisor
assert_delegate "agent talk --resume advisor" talk --resume advisor
assert_delegate "agent route writer draft intro" route writer draft intro
assert_delegate "agent invite theorist" invite theorist

telemetry_project="$(make_project)"
telemetry_out="$(cd "$telemetry_project" && PATH="$delegate_bin:$PATH" "$ael_abs" telemetry status)"
case "$telemetry_out" in
  *"AEL telemetry status: disabled"* )
    ;;
  *)
    printf '%s\n' "$telemetry_out"
    fail "ael telemetry status must remain AEL-handled"
    ;;
esac

stale_project="$(make_project)"
printf 'active_team = "agent-team"\n' >"$stale_project/.aiplus/team.toml"
stale_out="$(cd "$stale_project" && PATH="$delegate_bin:$PATH" "$ael_abs" advisor 2>&1)"
case "$stale_out" in
  *"team=agent-team, not aieconlab"*\
*"ARGS=agent talk advisor"*) ;;
  *)
    printf '%s\n' "$stale_out"
    fail "stale team config warning or delegate output missing"
    ;;
esac

old_bin="$(mktemp -d)"
cat >"$old_bin/aiplus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  printf 'aiplus 0.6.15\n'
  exit 0
fi
printf 'should not delegate\n'
SH
chmod +x "$old_bin/aiplus"
old_project="$(make_project)"
set +e
old_out="$(cd "$old_project" && PATH="$old_bin:$PATH" "$ael_abs" advisor 2>&1)"
old_status=$?
set -e
[ "$old_status" -ne 0 ] || fail "old aiplus delegate path should fail"
case "$old_out" in
  *"requires aiplus v0.6.16+"*"found 0.6.15"*) ;;
  *)
    printf '%s\n' "$old_out"
    fail "old aiplus error must explain required version"
    ;;
esac

dry_run="$(./ael install codex --dry-run)"
case "$dry_run" in
  *"AEL install dry-run"*\
*"runtime=codex"*\
*"would register the MCP server with codex"*\
*"AEL_DRY_RUN=PASS"*) ;;
  *)
    printf '%s\n' "$dry_run"
    fail "ael install codex --dry-run changed unexpectedly"
    ;;
esac

support_bin="$(mktemp)"
cat >"$support_bin" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'SUPPORT_ARGS=%s\n' "$*"
printf 'SUPPORT_BRAND=%s\n' "${AIPLUS_BRAND:-}"
SH
chmod +x "$support_bin"

status_project="$(make_project)"
status_out="$(cd "$status_project" && AEL_AIPLUS_BIN="$support_bin" "$ael_abs" status)"
case "$status_out" in
  *"SUPPORT_ARGS=agent status"*\
*"SUPPORT_BRAND=AEL"*) ;;
  *)
    printf '%s\n' "$status_out"
    fail "ael status must remain AEL-handled via support binary"
    ;;
esac

no_manifest="$(mktemp -d)"
auto_bin="$(mktemp -d)"
auto_support="$(mktemp)"
cat >"$auto_bin/codex" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$auto_support" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$AEL_SUPPORT_LOG"
exit 0
SH
chmod +x "$auto_bin/codex" "$auto_support"
auto_log="$(mktemp)"
auto_out="$(
  cd "$no_manifest" && \
    PATH="$delegate_bin:$auto_bin:$PATH" \
    AEL_AIPLUS_BIN="$auto_support" \
    AEL_SUPPORT_LOG="$auto_log" \
    "$ael_abs" pi
)"
case "$auto_out" in
  *"AEL set up for: codex"*\
*"ARGS=agent talk pi"*) ;;
  *)
    printf '%s\n' "$auto_out"
    fail "fresh role shortcut must auto-install then delegate"
    ;;
esac
case "$(cat "$auto_log")" in
  *"install codex --allow-version-skew"*\
*"add aieconlab"*\
*"agent set-team aieconlab"*\
*"mcp-register --runtime codex"*) ;;
  *)
    cat "$auto_log"
    fail "fresh role shortcut did not run AEL install flow"
    ;;
esac

echo "AEL_WRAPPER_TEST=PASS"
