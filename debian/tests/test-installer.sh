#!/usr/bin/env bash
# Offline regression tests. No sudo, APT, Homebrew, or user config is executed.
# Imports, shared state, mocked commands, and literal generated scripts are intentional.
# shellcheck disable=SC1091,SC2034,SC2317,SC2329,SC2016,SC2030,SC2031
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TEST_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TEST_WORK"' EXIT

(
    # shellcheck source=../install.sh
    source "$ROOT/install.sh"
    export HOME="$TEST_WORK/home"
    STATE_DIR="$HOME/.local/state/myconfig-debian"
    mkdir -p "$HOME/.config/app" "$TEST_WORK/source/deep" "$TEST_WORK/old-dir"
    printf old >"$HOME/.config/app/plain"
    printf new >"$TEST_WORK/source/plain"
    printf nested >"$TEST_WORK/source/deep/file"
    printf untouched >"$TEST_WORK/old-dir/file"
    ln -s "$TEST_WORK/old-dir" "$HOME/.config/app/deep"
    link_tree "$TEST_WORK/source" "$HOME/.config/app"
    [[ "$(cat "$HOME/.config/app/plain")" == new ]]
    [[ "$(cat "$BACKUP_ROOT/.config/app/plain")" == old ]]
    [[ "$(cat "$TEST_WORK/old-dir/file")" == untouched ]]
    [[ -L "$BACKUP_ROOT/.config/app/deep" ]]
    [[ "$(cat "$HOME/.config/app/deep/file")" == nested ]]
    before="$(find "$BACKUP_ROOT" -print | wc -l)"
    link_tree "$TEST_WORK/source" "$HOME/.config/app"
    [[ "$before" == "$(find "$BACKUP_ROOT" -print | wc -l)" ]]
    backup_and_link "$TEST_WORK/source/plain" "$HOME/.tmux.conf"
    backup_and_link "$TEST_WORK/source/plain" "$HOME/.config/tmux/tmux.conf"
    [[ "$(readlink -f "$HOME/.tmux.conf")" == "$(readlink -f "$HOME/.config/tmux/tmux.conf")" ]]
    printf 'PASS: backup, nested directory symlinks, repeat installation, tmux entry\n'
)

(
    # shellcheck source=../install-software.sh
    source "$ROOT/install-software.sh"
    SCRIPT_DIR="$TEST_WORK/manifests"
    mkdir -p "$SCRIPT_DIR"
    printf 'good\nblocked\n' >"$SCRIPT_DIR/test.txt"
    sudo() {
        # Batch fails; only the conflicting package fails when retried singly.
        [[ "${*: -1}" != blocked ]] || return 1
        return 0
    }
    install_apt_set test.txt
    [[ "${#FAILURES[@]}" == 1 && "${FAILURES[0]}" == 'APT blocked' ]]
    printf 'PASS: package conflict is recorded after individual retries\n'
)

(
    # shellcheck source=../install-software.sh
    source "$ROOT/install-software.sh"
    SCRIPT_DIR="$TEST_WORK/brew-manifests"
    STATE_DIR="$TEST_WORK/brew-state"
    mkdir -p "$SCRIPT_DIR" "$STATE_DIR" "$TEST_WORK/brew-bin"
    printf 'already-installed\nbroken\nafter-failure\n' >"$SCRIPT_DIR/brew-formulae.txt"
    printf 'codex\n' >"$SCRIPT_DIR/brew-casks.txt"
    cat >"$TEST_WORK/brew-bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_WORK/brew-calls"
case "$1" in
    shellenv) printf ':\n' ;;
    --prefix) printf '%s/brew-prefix\n' "$TEST_WORK" ;;
    update) exit 0 ;;
    list) [[ "${*: -1}" == already-installed ]] ;;
    install) [[ "${*: -1}" != broken ]] ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$TEST_WORK/brew-bin/brew"
    fc-cache() { return 0; }
    # This test focuses on package iteration; actual executable checks are
    # exercised separately by test-editor.sh.
    editor_check_language_servers() { return 0; }
    export TEST_WORK
    PATH="$TEST_WORK/brew-bin:$PATH"
    install_brew
    [[ "${#FAILURES[@]}" == 1 && "${FAILURES[0]}" == 'BREW formula broken' ]]
    grep -qx 'install --formula after-failure' "$TEST_WORK/brew-calls"
    grep -qx 'install --cask codex' "$TEST_WORK/brew-calls"
    if grep -qx 'install --formula already-installed' "$TEST_WORK/brew-calls"; then exit 1; fi
    [[ -s "$STATE_DIR/brew-prefix" ]]
    printf 'PASS: brew skips existing packages, continues after failures, installs casks\n'
)

(
    mkdir -p "$TEST_WORK/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$TEST_WORK/bin/slurp"
    printf '#!/usr/bin/env bash\nprintf unexpected >"$TEST_WORK/unexpected-screenshot"\n' >"$TEST_WORK/bin/grim"
    chmod +x "$TEST_WORK/bin/slurp" "$TEST_WORK/bin/grim"
    export TEST_WORK
    PATH="$TEST_WORK/bin:$PATH" bash "$ROOT/config/.local/bin/screenshot-region.sh"
    [[ ! -e "$TEST_WORK/unexpected-screenshot" ]]
    printf 'PASS: cancelling region selection does not capture the screen\n'
)

before="$(find "$TEST_WORK/home" -print | wc -l)"
HOME="$TEST_WORK/home" bash "$ROOT/install.sh" --dry-run >/dev/null
[[ "$before" == "$(find "$TEST_WORK/home" -print | wc -l)" ]]
printf 'PASS: dry-run does not modify HOME\n'
