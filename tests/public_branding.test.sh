#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

public_files=(
  README.md
  README.zh-CN.md
  install.sh
)

for file in "${public_files[@]}"; do
  [ -f "$file" ] || {
    echo "::error::missing public file: $file"
    exit 1
  }
  if [ "$file" = "install.sh" ] && grep -Eqi '\bAiPlus\b|\baiplus\b|\bAIPLUS\b' "$file"; then
    echo "::error file=$file::public-facing substrate brand leak"
    grep -Ein '\bAiPlus\b|\baiplus\b|\bAIPLUS\b' "$file"
    exit 1
  fi
done

if [ -d landing ]; then
  echo "::error::landing directory must not exist in README-only Tier 2 scope"
  exit 1
fi

# demo.gif was removed from the repo root in v0.2.0 (1.9 MB binary that
# every clone had to pull). Replacement is a hosted asset coming in
# v0.2.x. README sections are still required to exist — they just no
# longer point at a tracked binary.
[ ! -f demo.gif ] || {
  echo "::error::demo.gif should not be in repo (removed v0.2.0; use hosted asset)"
  exit 1
}
grep -Eq '^## Demo$|^## 演示$' README.md README.zh-CN.md || {
  echo "::error::README must keep a Demo section heading"
  exit 1
}
grep -q 'https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh' README.md || {
  echo "::error::README.md must use raw GitHub install URL"
  exit 1
}
grep -q 'https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh' README.zh-CN.md || {
  echo "::error::README.zh-CN.md must use raw GitHub install URL"
  exit 1
}
if grep -R -n 'ael\.zhiwen-wang\.com' README.md README.zh-CN.md install.sh tests; then
  echo "::error::custom domain reference remains in user-facing install surface"
  exit 1
fi
if grep -R -n 'landing/' README.md README.zh-CN.md; then
  echo "::error::landing path remains in README-only scope"
  exit 1
fi
if grep -Eq '\baiplus\b|\bAIPLUS\b' README.md README.zh-CN.md; then
  echo "::error::README must not expose lowercase substrate command names"
  exit 1
fi
grep -q '^## Advanced$' README.md || {
  echo "::error::README.md must keep Advanced substrate footnote"
  exit 1
}
grep -q '^## 高级说明$' README.zh-CN.md || {
  echo "::error::README.zh-CN.md must keep substrate footnote"
  exit 1
}

echo "AEL_PUBLIC_BRANDING_TEST=PASS"
