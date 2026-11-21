#!/usr/bin/env bash
# Offline tests: no installed editor, extension network access, or real user data.
# shellcheck disable=SC1091,SC2034,SC2329
set -Eeuo pipefail
TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"
TEST_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TEST_WORK"' EXIT

export HOME="$TEST_WORK/home" XDG_STATE_HOME="$TEST_WORK/state"
mkdir -p "$HOME"

# A dry-run must not invoke the editor or create install state, even if code exists.
code() { printf 'unexpected code invocation\n' >&2; return 99; }
export -f code
bash "$ROOT/install-vscode.sh" --dry-run >"$TEST_WORK/default-plan"
[[ "$(grep -c '^code ' "$TEST_WORK/default-plan")" == 19 ]]
grep -q -- '--install-extension ms-toolsai.jupyter[[:space:]]*$' "$TEST_WORK/default-plan"
if grep -Eq 'upgrade-agent|migrate-java|vscode-java-pack|codegeex' "$TEST_WORK/default-plan"; then exit 1; fi
[[ ! -e "$XDG_STATE_HOME" ]]
printf 'PASS: default plan preserves research tools without invoking code or writing state\n'

bash "$ROOT/install-vscode.sh" --bundle core --dry-run >"$TEST_WORK/core-plan"
[[ "$(grep -c '^code ' "$TEST_WORK/core-plan")" == 7 ]]
bash "$ROOT/install-vscode.sh" --bundle research --bundle remote --bundle research --profile 'Research Fast' --dry-run >"$TEST_WORK/combined-plan"
[[ "$(grep -c -- '--install-extension ms-vscode-remote.remote-ssh[[:space:]]*$' "$TEST_WORK/combined-plan")" == 1 ]]
[[ "$(grep -c '^code ' "$TEST_WORK/combined-plan")" == 21 ]]
grep -Fq -- 'code --profile Research\ Fast --install-extension' "$TEST_WORK/combined-plan"
printf 'PASS: core-only, repeated groups, deduplication and profile quoting\n'

for bad in '../research' missing; do
    status=0
    bash "$ROOT/install-vscode.sh" --bundle "$bad" --dry-run >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 ]]
done
[[ ! -e "$XDG_STATE_HOME" ]]
printf 'PASS: unknown or unsafe bundle names fail before mutations\n'

(
    source "$ROOT/install-vscode.sh"
    # Record each CLI argument separately to catch accidental splitting of profile names.
    code() {
        printf '<%s>' "$@" >>"$TEST_WORK/code-calls"
        printf '\n' >>"$TEST_WORK/code-calls"
        [[ "$*" != *Missing* && "${*: -1}" != example.broken ]]
    }
    status=0
    vscode_check_profile Missing >/dev/null 2>&1 || status="$?"
    [[ "$status" == 2 && ! -e "$XDG_STATE_HOME" ]]
    vscode_check_profile 'Research Fast'
    status=0
    vscode_install 'Research Fast' example.first example.broken example.after || status="$?"
    [[ "$status" == 1 ]]
    grep -Fqx '<--profile><Research Fast><--install-extension><example.after>' "$TEST_WORK/code-calls"
    [[ "$(cat "$XDG_STATE_HOME/myconfig-debian/failed-vscode-extensions.txt")" == example.broken ]]
    vscode_install '' example.first
    grep -Fqx '<--install-extension><example.first>' "$TEST_WORK/code-calls"
    [[ ! -s "$XDG_STATE_HOME/myconfig-debian/failed-vscode-extensions.txt" ]]
    printf 'PASS: missing-profile check, argument boundaries, failure continuation and reset\n'
)

bash "$ROOT/install-software.sh" --dry-run >"$TEST_WORK/software-plan"
grep -q 'VS Code: 19 explicit extension requests' "$TEST_WORK/software-plan"
grep -q -- '--install-extension ms-toolsai.jupyter[[:space:]]*$' "$TEST_WORK/software-plan"
printf 'PASS: one-click software plan includes the research extension group\n'
