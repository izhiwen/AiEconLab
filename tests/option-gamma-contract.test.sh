#!/usr/bin/env bash
# Option-gamma contract: a fresh `ael install` must result in
# .aiplus/agents/active-team.txt reading 'aieconlab'.
#
# Background: AEL repo gitignores .aiplus/agents/ runtime state and ships
# without an active-team file. End-users get aieconlab as the default team
# via the install-time call chain in ./ael:
#   - aiplus add aieconlab          (./ael line ~762, ~886)
#   - aiplus agent set-team aieconlab (./ael line ~772, ~887)
# This test enforces that contract.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  echo "::error::$1" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"

# Graceful skip in environments without aiplus (e.g., the lightweight
# validate-assets CI job). The contract is still exercised in install-smoke
# jobs where aiplus is installed. Pattern mirrors tests/install_sh.test.sh.
if ! command -v aiplus >/dev/null 2>&1; then
  echo "AEL_OPTION_GAMMA_CONTRACT_TEST=SKIP (aiplus not available in this environment)"
  exit 0
fi

CLONE_DIR="$TMP_DIR/AiEconLab"
export HOME="$TMP_DIR/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

echo "$ git clone $REPO_ROOT $CLONE_DIR"
git clone --quiet --no-hardlinks "$REPO_ROOT" "$CLONE_DIR"
git -C "$CLONE_DIR" checkout --quiet "$SOURCE_HEAD"

cd "$CLONE_DIR"

[ -f .aiplus/agents/active-team.txt ] \
  && fail "active-team.txt was shipped in the clone; Lane H gitignore is not in effect"

echo "$ ./ael install"
./ael install

ACTIVE_TEAM_FILE=".aiplus/agents/active-team.txt"
[ -f "$ACTIVE_TEAM_FILE" ] \
  || fail "$ACTIVE_TEAM_FILE missing after ./ael install — Option γ broken"

observed="$(tr -d '[:space:]' < "$ACTIVE_TEAM_FILE")"
[ "$observed" = "aieconlab" ] \
  || fail "active-team.txt='$observed' (expected 'aieconlab') — Option γ contract violated"

echo "PASS: option-gamma-contract: ael install yields active-team.txt='aieconlab'"
