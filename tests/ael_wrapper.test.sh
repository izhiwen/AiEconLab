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
[ "$version" = "AEL 0.3.0 (aiplus 0.6.19+)" ] || fail "unexpected ael version output: $version"

help="$(./ael --help)"
for cmd in "ael install" "ael update" "ael uninstall" "ael doctor" "ael status" "ael refresh"; do
  case "$help" in
    *"$cmd"*) ;;
    *) fail "ael --help missing AEL-specific command: $cmd" ;;
  esac
done
case "$help" in
  *"telemetry"*)
    fail "ael --help must not advertise telemetry"
    ;;
esac
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
  printf 'aiplus 0.6.19\n'
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
assert_delegate "agent talk --resume advisor" advisor
assert_delegate "agent talk advisor" advisor --fresh
assert_delegate "agent talk 我想反思 RD 设计" "我想反思 RD 设计"
assert_delegate "" chat
assert_delegate "agent talk --resume advisor" talk --resume advisor
assert_delegate "agent route writer draft intro" route writer draft intro
assert_delegate "agent invite theorist" invite theorist

unknown_project="$(make_project)"
set +e
unknown_out="$(cd "$unknown_project" && PATH="$delegate_bin:$PATH" "$ael_abs" foo bar baz 2>&1)"
unknown_status=$?
set -e
[ "$unknown_status" -ne 0 ] || fail "unknown multi-arg command must fail"
case "$unknown_out" in
  *"unknown command or multi-word natural-language input"*\
*"ael \"...\""*) ;;
  *"ARGS="*)
    printf '%s\n' "$unknown_out"
    fail "unknown multi-arg command must not delegate to substrate"
    ;;
  *)
    printf '%s\n' "$unknown_out"
    fail "unknown multi-arg error missing guidance"
    ;;
esac

chat_args_project="$(make_project)"
set +e
chat_args_out="$(cd "$chat_args_project" && PATH="$delegate_bin:$PATH" "$ael_abs" chat advisor 2>&1)"
chat_args_status=$?
set -e
[ "$chat_args_status" -ne 0 ] || fail "ael chat with arguments must fail"
case "$chat_args_out" in
  *"\`ael chat\` does not accept arguments"*\
*"ael \"...\""*) ;;
  *"ARGS="*)
    printf '%s\n' "$chat_args_out"
    fail "ael chat with arguments must not delegate to substrate"
    ;;
  *)
    printf '%s\n' "$chat_args_out"
    fail "ael chat with arguments error missing guidance"
    ;;
esac

telemetry_project="$(make_project)"
set +e
telemetry_out="$(cd "$telemetry_project" && PATH="$delegate_bin:$PATH" "$ael_abs" telemetry status 2>&1)"
telemetry_status=$?
set -e
[ "$telemetry_status" -ne 0 ] || fail "ael telemetry must be removed"
case "$telemetry_out" in
  *"ael telemetry has been removed"*) ;;
  *)
    printf '%s\n' "$telemetry_out"
    fail "ael telemetry removal error changed unexpectedly"
    ;;
esac

stale_project="$(make_project)"
printf 'active_team = "agent-team"\n' >"$stale_project/.aiplus/team.toml"
stale_out="$(cd "$stale_project" && PATH="$delegate_bin:$PATH" "$ael_abs" advisor 2>&1)"
case "$stale_out" in
  *"team=agent-team, not aieconlab"*\
*"ARGS=agent talk --resume advisor"*) ;;
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
  printf 'aiplus 0.6.18\n'
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
  *"requires aiplus v0.6.19+"*"found 0.6.18"*) ;;
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

refresh_project="$(make_project)"
refresh_out="$(cd "$refresh_project" && AEL_AIPLUS_BIN="$support_bin" "$ael_abs" refresh --dry-run)"
case "$refresh_out" in
  *"SUPPORT_ARGS=refresh --dry-run"*\
*"SUPPORT_BRAND=AEL"*) ;;
  *)
    printf '%s\n' "$refresh_out"
    fail "ael refresh must delegate explicitly to substrate refresh"
    ;;
esac

newer_path_bin="$(mktemp -d)"
cat >"$newer_path_bin/aiplus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version)
    printf 'aiplus 0.7.5\n'
    ;;
  identity)
    printf 'Usage: aiplus identity [--with-memory]\n'
    ;;
  *)
    printf 'PATH_AIPLUS_ARGS=%s\n' "$*"
    ;;
esac
SH
chmod +x "$newer_path_bin/aiplus"
older_support_bin="$(mktemp)"
cat >"$older_support_bin" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version)
    printf 'aiplus 0.6.20\n'
    ;;
  doctor)
    printf 'DOCTOR_STATUS=PASS\n'
    ;;
  *)
    printf 'SUPPORT_ARGS=%s\n' "$*"
    ;;
esac
SH
chmod +x "$older_support_bin"
newer_path_project="$(make_project)"
mkdir -p "$newer_path_project/.aiplus"
printf 'managed instructions\n' >"$newer_path_project/.aiplus/AGENTS.aiplus.md"
newer_path_out="$(cd "$newer_path_project" && PATH="$newer_path_bin:$PATH" AEL_AIPLUS_BIN="$older_support_bin" "$ael_abs" doctor 2>&1)"
case "$newer_path_out" in
  *"NEEDS_FIX aiplus_version_mismatch"*)
    printf '%s\n' "$newer_path_out"
    fail "ael doctor must not downgrade-warn when PATH aiplus is newer than bundled support"
    ;;
  *"DOCTOR_STATUS=PASS"*) ;;
  *)
    printf '%s\n' "$newer_path_out"
    fail "ael doctor newer PATH smoke output missing expected doctor status"
    ;;
esac

ael_consultant_project="$(make_project)"
cp core/templates/consultant-team.aieconlab.toml "$ael_consultant_project/.aiplus/consultant-team.toml"
ael_consultant_out="$(
  cd "$ael_consultant_project" && \
    PATH="$newer_path_bin:$PATH" \
    AEL_AIPLUS_BIN="$older_support_bin" \
    "$ael_abs" doctor 2>&1
)"
case "$ael_consultant_out" in
  *"PASS ael_consultant_team_research_config"*) ;;
  *)
    printf '%s\n' "$ael_consultant_out"
    fail "ael doctor must pass the AEL research consultant team config"
    ;;
esac

default_consultant_project="$(make_project)"
cp vendor/aiplus/assets/aiplus-auto-team-consultant/core/templates/consultant-team.default.toml \
  "$default_consultant_project/.aiplus/consultant-team.toml"
set +e
default_consultant_out="$(
  cd "$default_consultant_project" && \
    PATH="$newer_path_bin:$PATH" \
    AEL_AIPLUS_BIN="$older_support_bin" \
    "$ael_abs" doctor 2>&1
)"
default_consultant_status=$?
set -e
[ "$default_consultant_status" -ne 0 ] || fail "ael doctor must fail when AEL project has default SWE consultant config"
case "$default_consultant_out" in
  *"NEEDS_FIX ael_consultant_team_mismatch"*) ;;
  *)
    printf '%s\n' "$default_consultant_out"
    fail "ael doctor must flag default SWE consultant config under AEL"
    ;;
esac

update_tmp="$(mktemp -d)"
update_install="$update_tmp/install/bin"
update_libexec="$update_tmp/install/libexec"
update_release="$update_tmp/release"
update_pkg="$update_tmp/pkg/ael-v9.9.9"
mkdir -p "$update_install" "$update_libexec" "$update_release" "$update_pkg/bin" "$update_pkg/libexec"
cat >"$update_install/ael" <<'SH'
#!/usr/bin/env bash
printf 'AEL 0.3.0 (aiplus 0.6.19+)\n'
SH
cat >"$update_pkg/bin/ael" <<'SH'
#!/usr/bin/env bash
printf 'AEL 9.9.9 (aiplus 0.6.19+)\n'
SH
cat >"$update_pkg/libexec/ael-support" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  --version)
    printf 'aiplus 0.6.20\n'
    ;;
  *)
    printf 'UPDATED_SUPPORT_ARGS=%s\n' "$*"
    ;;
esac
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
  (cd "$update_release" && shasum -a 256 "$update_asset" >"$update_asset.sha256")
else
  (cd "$update_release" && sha256sum "$update_asset" >"$update_asset.sha256")
fi
update_out="$(
  PATH="$newer_path_bin:$PATH" \
  AEL_UPDATE_LATEST_VERSION=9.9.9 \
  AEL_BASE_URL="file://$update_release" \
  AEL_INSTALL_DIR="$update_install" \
  AEL_LIBEXEC_DIR="$update_libexec" \
  "$ael_abs" update 2>&1
)"
case "$update_out" in
  *"aiplus_sync=skipped reason=path_newer"*\
*"version=0.7.5"*\
*"bundled_version=0.6.20"*\
*"UPDATE_STATUS=PASS"*) ;;
  *)
    printf '%s\n' "$update_out"
    fail "ael update must not overwrite a newer PATH aiplus with older bundled support"
    ;;
esac
post_update_path_version="$(PATH="$newer_path_bin:$PATH" aiplus --version)"
[ "$post_update_path_version" = "aiplus 0.7.5" ] || {
  printf '%s\n' "$post_update_path_version"
  fail "ael update downgraded PATH aiplus"
}

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
*"ARGS=agent talk --resume pi"*) ;;
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
