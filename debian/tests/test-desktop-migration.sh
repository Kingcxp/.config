#!/usr/bin/env bash
# Offline tests; every privileged/package action is mocked.
# Mock overrides are called through sourced installer functions.
# shellcheck disable=SC1091,SC2034,SC2317,SC2329,SC2030,SC2031
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TEST_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TEST_WORK"' EXIT
export HOME="$TEST_WORK/home" XDG_STATE_HOME="$TEST_WORK/state"
mkdir -p "$HOME"
source "$ROOT/lib/desktop-migration.sh"

printf 'Remv plasma-desktop [1]\nPurg plasma-workspace:amd64 [1]\n' >"$TEST_WORK/plan"
desktop_check_plan "$TEST_WORK/plan" plasma-desktop plasma-workspace
printf 'Remv network-manager [1]\n' >>"$TEST_WORK/plan"
status=0
desktop_check_plan "$TEST_WORK/plan" plasma-desktop plasma-workspace >/dev/null 2>&1 || status="$?"
[[ "$status" == 2 ]]
printf 'PASS: removal guard accepts explicit desktop packages and rejects network removal\n'

(
    sudo() { [[ "$1" == test ]] || printf unexpected >"$TEST_WORK/greeter-unsafe"; return 1; }
    status=0
    desktop_configure_greeter >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 && ! -e "$TEST_WORK/greeter-unsafe" ]]
    printf 'PASS: a missing login theme never replaces the existing greeter configuration\n'
)

(
    pgrep() { return 0; }
    status=0
    desktop_check_session >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 ]]
    printf 'PASS: a running Plasma session blocks removal\n'
)

(
    SSH_CONNECTION='192.0.2.10 40000 192.0.2.20 22'
    export SSH_CONNECTION
    status=0
    desktop_check_session >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 ]]
    printf 'PASS: a remote SSH session blocks the desktop migration\n'
)

(
    desktop_installed() { return 0; }
    sudo() {
        printf '%s\n' "$*" >>"$TEST_WORK/power-calls"
        if [[ "$*" == *--simulate* ]]; then printf 'Remv power-profiles-daemon [1]\n'; fi
    }
    desktop_power_transition
    grep -q 'apt-get install -y -t trixie-backports tlp tlp-pd' "$TEST_WORK/power-calls"
    sudo() {
        if [[ "$*" == *--simulate* ]]; then printf 'Remv network-manager [1]\n'; return 0; fi
        printf unexpected >"$TEST_WORK/power-unsafe"
    }
    status=0
    desktop_power_transition >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 && ! -e "$TEST_WORK/power-unsafe" ]]
    printf 'PASS: power-manager replacement permits only the intended removal\n'
)

(
    pgrep() { return 1; }
    bash() { return 1; } # Simulate missing/invalid new desktop.
    sudo() { printf unexpected >"$TEST_WORK/unsafe-purge"; }
    status=0
    desktop_remove_kde || status="$?"
    [[ "$status" == 2 && ! -e "$TEST_WORK/unsafe-purge" ]]
    printf 'PASS: failed desktop verification prevents any removal\n'
)

(
    pgrep() { return 1; }
    bash() { return 0; }
    desktop_installed() { [[ "$1" == plasma-desktop ]]; }
    dpkg-query() { printf 'plasma-desktop\t1\n'; }
    sudo() {
        if [[ "$*" == *--simulate* ]]; then printf 'Remv sddm [1]\n'; return 0; fi
        if [[ "$1" != apt-mark ]]; then printf unexpected >"$TEST_WORK/unsafe-purge"; fi
    }
    status=0
    desktop_remove_kde >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 && ! -e "$TEST_WORK/unsafe-purge" ]]
    printf 'PASS: an unexpected display-manager removal is blocked before purge\n'
)

bash "$ROOT/install.sh" --mirror nju --dry-run >"$TEST_WORK/full-plan"
grep -q 'Debian mirror=nju' "$TEST_WORK/full-plan"
grep -q 'simulate explicit KDE removal' "$TEST_WORK/full-plan"
bash "$ROOT/install.sh" --keep-kde --dry-run >"$TEST_WORK/keep-plan"
if grep -q 'simulate explicit KDE removal' "$TEST_WORK/keep-plan"; then exit 1; fi
bash "$ROOT/install.sh" --configs-only --dry-run >"$TEST_WORK/config-plan"
if grep -q 'APT:' "$TEST_WORK/config-plan"; then exit 1; fi
before="$(find "$HOME" -print | wc -l)"
bash "$ROOT/install.sh" --refresh --dry-run >"$TEST_WORK/refresh-plan"
[[ "$before" == "$(find "$HOME" -print | wc -l)" ]]
grep -q 'install missing desktop prerequisites' "$TEST_WORK/refresh-plan"
grep -q 'refresh Waybar, Fcitx, network and USB tray apps in an active Hyprland session' "$TEST_WORK/refresh-plan"
grep -q 'No full software-manifest install or KDE removal' "$TEST_WORK/refresh-plan"
status=0
bash "$ROOT/install.sh" --refresh --mirror nju --dry-run >/dev/null 2>&1 || status="$?"
[[ "$status" == 2 ]]
printf 'PASS: mirror selection, keep-KDE, user-config-only and unified desktop-refresh plans\n'

(
    source "$ROOT/install.sh"
    desktop_install_login() { printf 'login\n' >>"$TEST_WORK/finalize"; }
    desktop_remove_kde() { printf 'remove\n' >>"$TEST_WORK/finalize"; }
    finish_desktop_install false true 0
    [[ "$(cat "$TEST_WORK/finalize")" == $'login\nremove' ]]
    : >"$TEST_WORK/finalize"
    finish_desktop_install false true 1
    [[ "$(cat "$TEST_WORK/finalize")" == login ]]
    : >"$TEST_WORK/finalize"
    finish_desktop_install true false 0
    [[ ! -s "$TEST_WORK/finalize" ]]
    finish_desktop_install false false 0
    [[ "$(cat "$TEST_WORK/finalize")" == login ]]
    : >"$TEST_WORK/finalize"
    desktop_install_login() { return 1; }
    status=0
    finish_desktop_install false true 0 || status="$?"
    [[ "$status" == 2 && ! -s "$TEST_WORK/finalize" ]]
    printf 'PASS: finalization orders login before removal and retains KDE on any install/login failure\n'
)
