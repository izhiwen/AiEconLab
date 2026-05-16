#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

public_files=(
  README.md
  README.zh-CN.md
  landing/index.html
  install.sh
)

for file in "${public_files[@]}"; do
  [ -f "$file" ] || {
    echo "::error::missing public file: $file"
    exit 1
  }
  if grep -Eqi '\bAiPlus\b|\baiplus\b|\bAIPLUS\b' "$file"; then
    echo "::error file=$file::public-facing substrate brand leak"
    grep -Ein '\bAiPlus\b|\baiplus\b|\bAIPLUS\b' "$file"
    exit 1
  fi
done

grep -q 'landing/demo.gif' README.md || {
  echo "::error::README.md must point at landing/demo.gif"
  exit 1
}
grep -q 'ael install' landing/index.html || {
  echo "::error::landing page missing ael install command"
  exit 1
}

echo "AEL_PUBLIC_BRANDING_TEST=PASS"
