#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash -n install.sh

latest_tmp="$(mktemp -d)"
latest_fake_bin="$latest_tmp/bin"
latest_count="$latest_tmp/curl.count"
mkdir -p "$latest_fake_bin"
cat >"$latest_fake_bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${AEL_TEST_CURL_COUNT:?}"
count=0
if [ -f "$AEL_TEST_CURL_COUNT" ]; then
  count="$(cat "$AEL_TEST_CURL_COUNT")"
fi
printf '%s\n' "$((count + 1))" > "$AEL_TEST_CURL_COUNT"
printf 'https://github.com/izhiwen/AiEconLab/releases/tag/v9.9.9'
SH
chmod +x "$latest_fake_bin/curl"

dry_run="$(PATH="$latest_fake_bin:$PATH" AEL_TEST_CURL_COUNT="$latest_count" sh install.sh --dry-run)"
case "$dry_run" in
  *"version=v9.9.9"*) ;;
  *)
    echo "::error::install.sh default version must resolve latest release"
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
latest_calls="$(cat "$latest_count")"
[ "$latest_calls" = "1" ] || {
  echo "::error::install.sh latest release lookup should call curl once, got $latest_calls"
  exit 1
}
fallback_fake_bin="$latest_tmp/fallback-bin"
mkdir -p "$fallback_fake_bin"
cat >"$fallback_fake_bin/curl" <<'SH'
#!/usr/bin/env bash
exit 22
SH
chmod +x "$fallback_fake_bin/curl"
fallback_output="$(PATH="$fallback_fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" AEL_MINIMUM_SUPPORTED_VERSION=v0.1.4 sh install.sh --dry-run 2>&1 || true)"
case "$fallback_output" in
  *"version=v0.1.4"*"WARN could not resolve latest AEL release"*|*"WARN could not resolve latest AEL release"*"version=v0.1.4"*) ;;
  *)
    echo "::error::install.sh must fall back clearly when latest lookup fails"
    printf '%s\n' "$fallback_output"
    exit 1
    ;;
esac
if grep -Eq 'AEL_DEFAULT_VERSION|v0\.1\.' install.sh; then
  echo "::error::install.sh must not contain hardcoded v0.1.x default literals"
  exit 1
fi

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
