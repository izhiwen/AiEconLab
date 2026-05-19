#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash -n install.sh

# v0.2.0 dropped Linux x86_64. CI runs this test on ubuntu-latest, where
# install.sh now legitimately refuses. We split the assertions:
#
#   1. Negative path (no fake): on real Linux, install.sh exits non-zero
#      with the "dropped" message AND a useful Windows download URL.
#   2. Positive path (with fake uname): install.sh proceeds as if on
#      Darwin arm64. Exercises version resolution, fallback, --add-to-path.

# === Negative path: only assertable on a dropped platform ===
# Skip if we're running on a SUPPORTED platform (Darwin arm64) since
# install.sh will succeed there. The negative path is exercised by
# the Linux CI runner, which is the platform we explicitly dropped.
case "$(/usr/bin/uname -s):$(/usr/bin/uname -m)" in
  Darwin:arm64)
    : # supported platform — skip negative assertion
    ;;
  *)
    real_drop_out="$(sh install.sh --dry-run 2>&1 || true)"
    case "$real_drop_out" in
      *"Dropped platforms in v0.2.0"*) ;;
      *)
        echo "::error::install.sh on dropped platform must print 'Dropped platforms in v0.2.0' message"
        printf '%s\n' "$real_drop_out"
        exit 1
        ;;
    esac
    case "$real_drop_out" in
      *"windows-x86_64.tar.gz"*) ;;
      *)
        echo "::error::install.sh dropped-platform message must point Windows users at the right asset URL"
        printf '%s\n' "$real_drop_out"
        exit 1
        ;;
    esac
    ;;
esac

# === Set up fake uname for the rest of the test ===
fake_bin="$(mktemp -d)"
cat > "$fake_bin/uname" <<'FAKE'
#!/bin/sh
case "$1" in
  -s) echo "Darwin" ;;
  -m) echo "arm64" ;;
  *) /usr/bin/uname "$@" ;;
esac
FAKE
chmod +x "$fake_bin/uname"
export PATH="$fake_bin:$PATH"

latest_root="$(mktemp -d)"
mkdir -p "$latest_root/tag/v9.9.9"
: > "$latest_root/tag/v9.9.9/index.html"

dry_run="$(
  AEL_RELEASES_LATEST_URL="file://$latest_root/tag/v9.9.9/index.html" \
  sh install.sh --dry-run
)"
case "$dry_run" in
  *"version=v9.9.9"*) ;;
  *)
    echo "::error::install.sh default version must resolve the latest release"
    printf '%s\n' "$dry_run"
    exit 1
    ;;
esac
case "$dry_run" in
  *AiPlus*|*aiplus*|*AIPLUS*)
    echo "::error::install.sh dry-run leaks substrate branding"
    printf '%s\n' "$dry_run"
    exit 1
    ;;
esac

fallback_output="$(
  AEL_RELEASES_LATEST_URL="file://$latest_root/missing" \
  sh install.sh --dry-run 2>&1
)"
case "$fallback_output" in
  *"WARNING could not resolve latest AEL release"*) ;;
  *)
    echo "::error::install.sh must warn and fall back when latest lookup fails"
    printf '%s\n' "$fallback_output"
    exit 1
    ;;
esac
case "$fallback_output" in
  *"version=v0.1.0"*) ;;
  *)
    echo "::error::install.sh fallback must use the minimum supported version"
    printf '%s\n' "$fallback_output"
    exit 1
    ;;
esac

tmp="$(mktemp -d)"
release_dir="$tmp/release"
package_root="$tmp/pkg/ael-v9.9.9-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
mkdir -p "$release_dir" "$package_root/bin" "$package_root/libexec"

cat >"$package_root/bin/ael" <<'SH'
#!/usr/bin/env bash
echo "fake ael"
SH
cat >"$package_root/libexec/ael-support" <<'SH'
#!/usr/bin/env bash
echo "fake support"
SH
chmod +x "$package_root/bin/ael" "$package_root/libexec/ael-support"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  arm64|aarch64) arch="aarch64" ;;
  x86_64|amd64) arch="x86_64" ;;
esac
asset="ael-v9.9.9-$os-$arch.tar.gz"
tar -C "$tmp/pkg" -czf "$release_dir/$asset" "$(basename "$package_root")"
if command -v shasum >/dev/null 2>&1; then
  (cd "$release_dir" && shasum -a 256 "$asset" > "$asset.sha256")
else
  (cd "$release_dir" && sha256sum "$asset" > "$asset.sha256")
fi

install_root="$tmp/install"
output="$(
  AEL_VERSION=v9.9.9 \
  AEL_BASE_URL="file://$release_dir" \
  AEL_INSTALL_DIR="$install_root/bin" \
  AEL_LIBEXEC_DIR="$install_root/libexec" \
  sh install.sh
)"

case "$output" in
  *INSTALL_STATUS=PASS*) ;;
  *)
    echo "::error::install.sh did not report pass"
    printf '%s\n' "$output"
    exit 1
    ;;
esac
case "$output" in
  *"PATH_NOTICE=$install_root/bin is not on PATH"*) ;;
  *)
    echo "::error::install.sh without --add-to-path should keep manual PATH notice behavior"
    printf '%s\n' "$output"
    exit 1
    ;;
esac

[ -x "$install_root/bin/ael" ] || {
  echo "::error::ael wrapper not installed"
  exit 1
}
[ -x "$install_root/libexec/ael-support" ] || {
  echo "::error::support binary not installed"
  exit 1
}

path_home="$tmp/path-home"
mkdir -p "$path_home"
path_output_1="$(
  HOME="$path_home" \
  SHELL="/bin/zsh" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  AEL_VERSION=v9.9.9 \
  AEL_BASE_URL="file://$release_dir" \
  sh install.sh --add-to-path
)"
case "$path_output_1" in
  *"PATH_PROFILE_APPENDED=~/.zshrc"*) ;;
  *)
    echo "::error::install.sh --add-to-path must append to zsh profile"
    printf '%s\n' "$path_output_1"
    exit 1
    ;;
esac
case "$path_output_1" in
  *"restart your shell or run: source ~/.zshrc"*) ;;
  *)
    echo "::error::install.sh --add-to-path must print source hint"
    printf '%s\n' "$path_output_1"
    exit 1
    ;;
esac
path_output_2="$(
  HOME="$path_home" \
  SHELL="/bin/zsh" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  AEL_VERSION=v9.9.9 \
  AEL_BASE_URL="file://$release_dir" \
  sh install.sh --add-to-path
)"
case "$path_output_2" in
  *"PATH_PROFILE_ALREADY_CONFIGURED=~/.zshrc"*) ;;
  *)
    echo "::error::install.sh --add-to-path must be idempotent"
    printf '%s\n' "$path_output_2"
    exit 1
    ;;
esac
expected_path_line="export PATH=\"$path_home/.local/bin:\$PATH\""
path_line_count="$(grep -Fxc "$expected_path_line" "$path_home/.zshrc")"
[ "$path_line_count" = "1" ] || {
  echo "::error::install.sh --add-to-path should append exactly one PATH line, got $path_line_count"
  cat "$path_home/.zshrc"
  exit 1
}

echo "AEL_INSTALL_SH_TEST=PASS"
