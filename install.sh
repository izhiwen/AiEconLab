#!/bin/sh
set -eu

REPO="izhiwen/AiEconLab"
AEL_VERSION_VALUE="${AEL_VERSION:-}"
AEL_MINIMUM_SUPPORTED_VERSION="${AEL_MINIMUM_SUPPORTED_VERSION:-v0.$(printf '%s.%s' 1 4)}"
INSTALL_DIR="${AEL_INSTALL_DIR:-$HOME/.local/bin}"
LIBEXEC_DIR="${AEL_LIBEXEC_DIR:-$(dirname "$INSTALL_DIR")/libexec}"
DRY_RUN=0
ADD_TO_PATH=0
LATEST_VERSION_CACHE=""

usage() {
  cat <<'USAGE'
Install the ael command.

Usage:
  sh install.sh [--dry-run] [--add-to-path]

Environment:
  AEL_VERSION      Release version to install, default latest GitHub release
  AEL_INSTALL_DIR  Install directory for the ael wrapper, default $HOME/.local/bin
  AEL_LIBEXEC_DIR  Install directory for bundled runtime support, default ../libexec
  AEL_BASE_URL     Override release base URL for tests/mirrors

Flags:
  --dry-run        Print what would happen without writing
  --add-to-path    Append the install directory to your shell profile if needed
  -h, --help       Show this help

The installer downloads the AEL release package for this platform, verifies the
package SHA256 sidecar, and installs:
  - ael wrapper to $AEL_INSTALL_DIR/ael
  - bundled runtime support to $AEL_LIBEXEC_DIR/ael-support

It does not require sudo, install project files, upload data, collect telemetry,
or modify Codex/Claude Code/OpenCode config. It edits shell profiles only when
--add-to-path is set.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --add-to-path)
      ADD_TO_PATH=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR required command not found: $1" >&2
    exit 1
  fi
}

resolve_version() {
  if [ -n "$AEL_VERSION_VALUE" ]; then
    echo "$AEL_VERSION_VALUE"
    return 0
  fi
  resolve_latest_version
}

resolve_latest_version() {
  if [ -n "${AEL_LATEST_VERSION:-}" ]; then
    LATEST_VERSION_CACHE="$AEL_LATEST_VERSION"
    echo "$LATEST_VERSION_CACHE"
    return 0
  fi
  if [ -n "$LATEST_VERSION_CACHE" ]; then
    echo "$LATEST_VERSION_CACHE"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    latest_effective="$(
      curl -fsSL -o /dev/null -w '%{url_effective}' \
        "https://github.com/$REPO/releases/latest" 2>/dev/null || true
    )"
    latest_version="$(printf '%s' "$latest_effective" | sed -E 's#^.*/tag/##')"
    case "$latest_version" in
      v[0-9]*)
        LATEST_VERSION_CACHE="$latest_version"
        echo "$LATEST_VERSION_CACHE"
        return 0
        ;;
    esac
  fi

  echo "WARN could not resolve latest AEL release; falling back to minimum supported $AEL_MINIMUM_SUPPORTED_VERSION" >&2
  LATEST_VERSION_CACHE="$AEL_MINIMUM_SUPPORTED_VERSION"
  echo "$LATEST_VERSION_CACHE"
}

detect_asset() {
  version_no_v="$(printf '%s' "$VERSION" | sed 's/^v//')"
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
  esac
  case "$os:$arch" in
    Darwin:aarch64|Darwin:x86_64)
      echo "ael-v$version_no_v-darwin-$arch.tar.gz"
      ;;
    Linux:aarch64|Linux:x86_64)
      echo "ael-v$version_no_v-linux-$arch.tar.gz"
      ;;
    *)
      echo "ERROR no AEL $VERSION package for: $os $arch" >&2
      echo "Supported platforms: macOS arm64/x86_64 and Linux arm64/x86_64." >&2
      exit 1
      ;;
  esac
}

fetch() {
  src="$1"
  dst="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$src" -o "$dst"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$src" -O "$dst"
  else
    echo "ERROR curl or wget is required" >&2
    exit 1
  fi
}

profile_display() {
  path="$1"
  case "$path" in
    "$HOME"/*)
      echo "~/${path#"$HOME"/}"
      ;;
    *)
      echo "$path"
      ;;
  esac
}

append_path_to_profile() {
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh)
      profile="$HOME/.zshrc"
      line="export PATH=\"$INSTALL_DIR:\$PATH\""
      source_hint="source ~/.zshrc"
      ;;
    bash)
      profile="$HOME/.bashrc"
      line="export PATH=\"$INSTALL_DIR:\$PATH\""
      source_hint="source ~/.bashrc"
      ;;
    fish)
      profile="$HOME/.config/fish/config.fish"
      line="set -gx PATH \"$INSTALL_DIR\" \$PATH"
      source_hint="source ~/.config/fish/config.fish"
      mkdir -p "$(dirname "$profile")"
      ;;
    *)
      echo "ERROR unsupported shell for --add-to-path: ${SHELL:-unknown}" >&2
      echo "Add this to your shell profile manually:" >&2
      echo "  export PATH=\"$INSTALL_DIR:\$PATH\"" >&2
      exit 1
      ;;
  esac

  touch "$profile"
  display="$(profile_display "$profile")"
  if grep -Fqx "$line" "$profile"; then
    echo "PATH_PROFILE_ALREADY_CONFIGURED=$display"
    echo "$display already contains the AEL PATH line"
    echo "restart your shell or run: $source_hint"
    return 0
  fi
  printf '%s\n' "$line" >> "$profile"
  echo "PATH_PROFILE_APPENDED=$display"
  echo "appended to $display"
  echo "restart your shell or run: $source_hint"
}

sha256_verify() {
  sidecar="$1"
  asset="$2"
  asset_name="$(basename "$asset")"
  expected="$(awk '{print $1}' "$sidecar" | head -n 1)"
  if [ -z "$expected" ]; then
    echo "ERROR checksum sidecar is empty: $sidecar" >&2
    exit 1
  fi
  printf '%s  %s\n' "$expected" "$asset_name" > "$TMP_DIR/asset.sha256"
  if command -v shasum >/dev/null 2>&1; then
    (cd "$(dirname "$asset")" && shasum -a 256 -c "$TMP_DIR/asset.sha256")
  elif command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$asset")" && sha256sum -c "$TMP_DIR/asset.sha256")
  else
    echo "ERROR shasum or sha256sum is required for checksum verification" >&2
    exit 1
  fi
}

need_cmd uname
need_cmd mktemp
need_cmd tar
need_cmd chmod
need_cmd basename

VERSION="$(resolve_version)"
ASSET="$(detect_asset)"
BASE_URL="${AEL_BASE_URL:-https://github.com/$REPO/releases/download/$VERSION}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "AEL installer"
echo "version=$VERSION"
echo "asset=$ASSET"
echo "install_dir=$INSTALL_DIR"
echo "libexec_dir=$LIBEXEC_DIR"
echo "writes=$INSTALL_DIR/ael"
if [ "$ADD_TO_PATH" -eq 1 ]; then
  echo "shell_profile_edits=opt-in"
else
  echo "shell_profile_edits=none"
fi
echo "telemetry=none"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY_RUN=YES"
  echo "download=$BASE_URL/$ASSET"
  echo "checksum=$BASE_URL/$ASSET.sha256"
  if [ "$ADD_TO_PATH" -eq 1 ]; then
    echo "add_to_path=would_update_profile_if_needed"
  fi
  exit 0
fi

fetch "$BASE_URL/$ASSET.sha256" "$TMP_DIR/$ASSET.sha256"
fetch "$BASE_URL/$ASSET" "$TMP_DIR/$ASSET"
sha256_verify "$TMP_DIR/$ASSET.sha256" "$TMP_DIR/$ASSET"

mkdir -p "$TMP_DIR/extract"
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR/extract"

AEL_BIN="$(find "$TMP_DIR/extract" -type f -path "*/bin/ael" | head -n 1)"
SUPPORT_BIN="$(find "$TMP_DIR/extract" -type f -path "*/libexec/ael-support" | head -n 1)"
if [ ! -f "$AEL_BIN" ]; then
  echo "ERROR release archive did not contain bin/ael" >&2
  exit 1
fi
if [ ! -f "$SUPPORT_BIN" ]; then
  echo "ERROR release archive did not contain libexec support binary" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$LIBEXEC_DIR"
cp "$AEL_BIN" "$INSTALL_DIR/ael"
cp "$SUPPORT_BIN" "$LIBEXEC_DIR/ael-support"
chmod 755 "$INSTALL_DIR/ael" "$LIBEXEC_DIR/ael-support"

echo "INSTALL_STATUS=PASS"
echo "installed=$INSTALL_DIR/ael"

case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ;;
  *)
    if [ "$ADD_TO_PATH" -eq 1 ]; then
      append_path_to_profile
    else
      echo "PATH_NOTICE=$INSTALL_DIR is not on PATH"
      echo "Add this to your shell profile if you want to run ael from any terminal:"
      echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
    ;;
esac

echo "Next:"
echo "  cd MyProject"
echo "  ael install                  # once per project — sets up the research team"
echo "  ael                          # opens the lobby — pick who to talk to (PI, Advisor, writer, ...)"
echo "  ael advisor                  # or jump straight to advisor"
echo "  ael pi                       # or straight to PI"
