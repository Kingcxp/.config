#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

# shellcheck source=../lib/install-appearance.sh
source "$ROOT/lib/install-appearance.sh"
THEME_INSTALL_ROOT="$TMP_DIR/root"

printf 'pinned Catppuccin test asset\n' >"$TMP_DIR/asset"
expected="$(sha256sum "$TMP_DIR/asset" | awk '{ print $1 }')"
verify_theme_archive "$TMP_DIR/asset" "$expected"
if verify_theme_archive "$TMP_DIR/asset" "$(printf '0%.0s' {1..64})"; then
    printf 'FAIL: incorrect theme hash was accepted\n' >&2
    exit 1
fi

mkdir -p "$TMP_DIR/source"
printf 'theme payload\n' >"$TMP_DIR/source/theme.txt"
target=/usr/local/share/themes/test-catppuccin-theme
install_managed_theme_tree "$TMP_DIR/source" "$target" v1 test-theme
[[ "$(<"$THEME_INSTALL_ROOT$target/.myconfig-managed")" == v1 ]]
[[ "$(<"$THEME_INSTALL_ROOT$target/theme.txt")" == 'theme payload' ]]
install_managed_theme_tree "$TMP_DIR/source" "$target" v1 test-theme

printf 'updated theme payload\n' >"$TMP_DIR/source/theme.txt"
install_managed_theme_tree "$TMP_DIR/source" "$target" v2 test-theme
[[ "$(<"$THEME_INSTALL_ROOT$target/.myconfig-managed")" == v2 ]]
[[ "$(<"$THEME_INSTALL_ROOT$target/theme.txt")" == 'updated theme payload' ]]
[[ "$(find "$THEME_INSTALL_ROOT/var/backups/myconfig-debian/themes" -mindepth 1 -maxdepth 1 -type d | wc -l)" == 1 ]]
printf 'PASS: Catppuccin asset checksum, idempotence, and managed-theme backup\n'
