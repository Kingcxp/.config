#!/usr/bin/env bash
# Offline transaction tests. Python uses an isolated APT directory; no real sudo/APT.
# shellcheck disable=SC1091,SC2034,SC2329
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TEST_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TEST_WORK"' EXIT
export HOME="$TEST_WORK/home" XDG_STATE_HOME="$TEST_WORK/state"
mkdir -p "$HOME" "$TEST_WORK/apt/sources.list.d"
printf 'deb https://deb.debian.org/debian trixie main\n' >"$TEST_WORK/apt/sources.list"
cp "$TEST_WORK/apt/sources.list" "$TEST_WORK/original"
source "$ROOT/switch-mirror.sh"
UPDATE_SUCCEEDS=false
sudo() {
    if [[ "$1" == python3 ]]; then
        shift
        "${PYTHON_COMMAND:-python3}" -B "$@" --root "$TEST_WORK/apt" --backup-root "$TEST_WORK/backups"
    elif [[ "$1" == apt-get ]]; then
        [[ "$*" == *APT::Update::Error-Mode=any* && "$*" == *Dir::Etc::sourceparts=-* ]]
        [[ "$UPDATE_SUCCEEDS" == true ]]
    else
        printf 'Unexpected privileged operation\n' >&2; return 99
    fi
}
status=0
mirror_apply nju || status="$?"
[[ "$status" == 1 ]]
cmp "$TEST_WORK/original" "$TEST_WORK/apt/sources.list"
[[ ! -e "$TEST_WORK/apt/sources.list.d/myconfig-debian.sources" && ! -e "$XDG_STATE_HOME/myconfig-debian/mirror" ]]
printf 'PASS: unreachable mirror restores original sources and does not save selection\n'

UPDATE_SUCCEEDS=true
mirror_apply nju
[[ "$(cat "$XDG_STATE_HOME/myconfig-debian/mirror")" == nju ]]
grep -q 'mirror.nju.edu.cn/debian-security' "$TEST_WORK/apt/sources.list.d/myconfig-debian.sources"
mirror_apply official
[[ "$(cat "$XDG_STATE_HOME/myconfig-debian/mirror")" == official ]]
if grep -q 'mirror.nju.edu.cn' "$TEST_WORK/apt/sources.list.d/myconfig-debian.sources"; then exit 1; fi
printf 'PASS: successful switches replace all Debian suites and save only the confirmed mirror\n'
