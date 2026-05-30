#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
  echo "VERSION_CONSISTENCY_FAIL: $*" >&2
  exit 1
}

[ -f VERSION ] || fail "missing VERSION"
version="$(cat VERSION)"
case "$version" in
  *$'\n'*|*" "*|"" )
    fail "VERSION must be a single non-empty token"
    ;;
esac
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "VERSION must be semantic X.Y.Z; got $version"
fi

actual="$(./ael --version 2>&1 | head -n 1)"
expected="AEL $version (aiplus 0.6.19+)"
if [ "$actual" != "$expected" ]; then
  fail "VERSION ($version) does not match wrapper output ($actual)"
fi

is_allowed_ael_literal() {
  case "$1" in
    ./.git/*|./vendor/*|./dist/*|./node_modules/*|./CHANGELOG.md:*|./docs/dev/*|./scripts/verify-version-consistency.sh:*)
      return 0
      ;;
    ./.github/workflows/install-smoke.yml:*"AEL 0.3.0"*)
      return 0
      ;;
    ./tests/ael_wrapper.test.sh:*"AEL 9.9.9"*)
      return 0
      ;;
    ./tests/install_ps1.test.ps1:*"AEL 9.9.9"*)
      return 0
      ;;
  esac
  return 1
}

is_allowed_v_literal() {
  case "$1" in
    ./.git/*|./vendor/*|./dist/*|./node_modules/*|./CHANGELOG.md:*|./docs/dev/*|./scripts/verify-version-consistency.sh:*)
      return 0
      ;;
    ./bin/ael.ps1:*MinimumSupported*|./install.ps1:*MinimumSupported*)
      return 0
      ;;
    ./.github/workflows/install-smoke.yml:*'AEL_VERSION = "v0.3.0"'*)
      return 0
      ;;
    ./tests/install_ps1.test.ps1:*'AEL_MINIMUM_SUPPORTED_VERSION = "v0.2.3"'*)
      return 0
      ;;
    ./tests/install_ps1.test.ps1:*'AEL_VERSION = "v9.9.9"'*)
      return 0
      ;;
  esac
  return 1
}

bad=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  if ! is_allowed_ael_literal "$line"; then
    echo "stale AEL version literal: $line" >&2
    bad=1
  fi
done < <(grep -RInE 'AEL [0-9]+\.[0-9]+\.[0-9]+' . \
  --exclude-dir=.git \
  --exclude-dir=vendor \
  --exclude-dir=dist \
  --exclude-dir=node_modules \
  --exclude-dir=.aiplus \
  --exclude-dir=.agents \
  --exclude-dir=.claude \
  --exclude-dir=.codex \
  --exclude-dir=.opencode || true)

while IFS= read -r line; do
  [ -n "$line" ] || continue
  if ! is_allowed_v_literal "$line"; then
    echo "stale quoted v-version literal: $line" >&2
    bad=1
  fi
done < <(grep -RInE '"v[0-9]+\.[0-9]+\.[0-9]+"' . \
  --exclude-dir=.git \
  --exclude-dir=vendor \
  --exclude-dir=dist \
  --exclude-dir=node_modules \
  --exclude-dir=.aiplus \
  --exclude-dir=.agents \
  --exclude-dir=.claude \
  --exclude-dir=.codex \
  --exclude-dir=.opencode || true)

[ "$bad" -eq 0 ] || fail "hardcoded current-version literals found"

echo "VERSION_CONSISTENCY_OK version=$version"
