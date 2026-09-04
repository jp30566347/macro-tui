#!/bin/sh
# Installs macro-tui from the latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/jp30566347/macro-tui/main/install.sh | sh
#
# Downloads the binary for this platform, verifies its checksum, and puts it in
# ~/.local/bin. Set MACRO_TUI_BIN_DIR to install somewhere else, or
# MACRO_TUI_VERSION to pin a tag.
#
# POSIX sh on purpose: this has to run under dash and busybox ash, not just
# bash.
set -eu

REPO="jp30566347/macro-tui"
BIN_DIR="${MACRO_TUI_BIN_DIR:-$HOME/.local/bin}"
VERSION="${MACRO_TUI_VERSION:-latest}"

say() { printf '%s\n' "$*"; }
# Diagnostics go to stderr so that piping this script somewhere cannot swallow
# the reason it stopped.
err() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || err "$1 is required but not installed"
}

target() {
    os=$(uname -s)
    arch=$(uname -m)
    case "$os" in
        Linux)
            case "$arch" in
                x86_64|amd64) echo "x86_64-unknown-linux-musl" ;;
                aarch64|arm64) echo "aarch64-unknown-linux-musl" ;;
                *) err "unsupported architecture: $arch" ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64) echo "x86_64-apple-darwin" ;;
                arm64) echo "aarch64-apple-darwin" ;;
                *) err "unsupported architecture: $arch" ;;
            esac
            ;;
        *)
            err "unsupported operating system: $os. Windows users can download the zip from https://github.com/$REPO/releases"
            ;;
    esac
}

need uname
need tar
if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -qO "$2" "$1"; }
else
    err "either curl or wget is required"
fi

TARGET=$(target)
if [ "$VERSION" = "latest" ]; then
    BASE="https://github.com/$REPO/releases/latest/download"
else
    BASE="https://github.com/$REPO/releases/download/$VERSION"
fi
ARCHIVE="macro-tui-$TARGET.tar.gz"

TMP=$(mktemp -d)
# Cleans up on success, failure and interrupt alike.
trap 'rm -rf "$TMP"' EXIT INT TERM

say "Downloading macro-tui ($TARGET)..."
fetch "$BASE/$ARCHIVE" "$TMP/$ARCHIVE" ||
    err "could not download $BASE/$ARCHIVE"

# Verified when a checksum tool is available. A missing sha256sum should not
# block the install, but a mismatch always does.
if fetch "$BASE/$ARCHIVE.sha256" "$TMP/$ARCHIVE.sha256" 2>/dev/null; then
    expected=$(cut -d' ' -f1 <"$TMP/$ARCHIVE.sha256")
    actual=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$TMP/$ARCHIVE" | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$TMP/$ARCHIVE" | cut -d' ' -f1)
    fi
    if [ -n "$actual" ]; then
        [ "$expected" = "$actual" ] || err "checksum mismatch: expected $expected, got $actual"
        say "Checksum verified."
    fi
fi

tar xzf "$TMP/$ARCHIVE" -C "$TMP" || err "could not unpack $ARCHIVE"
[ -f "$TMP/macro-tui" ] || err "archive did not contain a macro-tui binary"

mkdir -p "$BIN_DIR"
# Written to a temporary name first and then moved, so a running copy of
# macro-tui is never overwritten in place.
chmod +x "$TMP/macro-tui"
mv -f "$TMP/macro-tui" "$BIN_DIR/macro-tui.new"
mv -f "$BIN_DIR/macro-tui.new" "$BIN_DIR/macro-tui"

say ""
say "Installed $("$BIN_DIR/macro-tui" --version) to $BIN_DIR/macro-tui"

case ":${PATH}:" in
    *":$BIN_DIR:"*)
        say "Run it with: macro-tui"
        ;;
    *)
        say ""
        say "$BIN_DIR is not on your PATH. Add it with:"
        say ""
        say "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && exec bash"
        say ""
        say "Or run it directly: $BIN_DIR/macro-tui"
        ;;
esac
