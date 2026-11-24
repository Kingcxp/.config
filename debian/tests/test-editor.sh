#!/usr/bin/env bash
# Exercise custom PATHs, command/package name differences, and failed installs.
# shellcheck disable=SC1091,SC2034
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" XDG_STATE_HOME="$work/state" EDITOR_TEST_PREFIX="$work/custom-brew"
STATE_DIR="$XDG_STATE_HOME/myconfig-debian"
mkdir -p "$HOME" "$STATE_DIR" "$EDITOR_TEST_PREFIX/bin" "$EDITOR_TEST_PREFIX/opt/node@22/bin"
printf '%s\n' "$EDITOR_TEST_PREFIX" >"$STATE_DIR/brew-prefix"
export EDITOR_TEST_LOG="$work/brew-calls"
cat >"$EDITOR_TEST_PREFIX/bin/brew" <<'BREW'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$EDITOR_TEST_LOG"
case "$1" in
    --prefix) printf '%s\n' "$EDITOR_TEST_PREFIX" ;;
    install)
        [[ "$*" == 'install --formula vscode-langservers-extracted' ]]
        [[ "${EDITOR_TEST_BROKEN:-false}" != true ]] || exit 0
        for command_name in vscode-json-language-server vscode-html-language-server vscode-css-language-server; do
            printf '#!/bin/sh\nexit 0\n' >"$EDITOR_TEST_PREFIX/bin/$command_name"
            chmod +x "$EDITOR_TEST_PREFIX/bin/$command_name"
        done ;;
    link) exit 1 ;;
    *) exit 99 ;;
esac
BREW
chmod +x "$EDITOR_TEST_PREFIX/bin/brew"
printf '#!/bin/sh\nexit 0\n' >"$EDITOR_TEST_PREFIX/opt/node@22/bin/node"
chmod +x "$EDITOR_TEST_PREFIX/opt/node@22/bin/node"
# The older similarly named binary must not satisfy the jsonls requirement.
printf '#!/bin/sh\nexit 0\n' >"$EDITOR_TEST_PREFIX/bin/vscode-json-languageserver"
chmod +x "$EDITOR_TEST_PREFIX/bin/vscode-json-languageserver"
source "$ROOT/lib/configure-editor.sh"
editor_load_path
[[ "$(command -v node)" == "$EDITOR_TEST_PREFIX/opt/node@22/bin/node" ]]
if editor_check_language_servers true; then exit 1; fi
editor_ensure_language_servers
grep -qx 'install --formula vscode-langservers-extracted' "$EDITOR_TEST_LOG"
editor_check_language_servers
before="$(grep -c '^install ' "$EDITOR_TEST_LOG")"
editor_ensure_language_servers
[[ "$before" == "$(grep -c '^install ' "$EDITOR_TEST_LOG")" ]]
printf 'PASS: custom Homebrew/Node PATH, correct package/binary distinction, and no duplicate install\n'

rm -f -- "$EDITOR_TEST_PREFIX/bin/vscode-json-language-server"
export EDITOR_TEST_BROKEN=true
if editor_ensure_language_servers >"$work/broken-log" 2>&1; then exit 1; fi
grep -qx 'link vscode-langservers-extracted' "$EDITOR_TEST_LOG"
printf 'PASS: a successful package command without the required executable is not reported as complete\n'

before="$(find "$HOME" -print | wc -l)"
bash "$ROOT/install.sh" --editor --dry-run >"$work/plan"
[[ "$before" == "$(find "$HOME" -print | wc -l)" ]]
grep -q 'No desktop, APT, GRUB, or KDE changes' "$work/plan"
for argument in --refresh --configs-only --keep-kde; do
    status=0
    bash "$ROOT/install.sh" --editor "$argument" --dry-run >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 ]]
done
printf 'PASS: editor-only preview changes no configuration and rejects conflicting install modes\n'
