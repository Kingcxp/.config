#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)"

(
    # shellcheck source=../install-software.sh
    source "$ROOT/install-software.sh"
    uefi_mode_active() { return 0; }
    efi_system_partition() { printf '/boot/efi\n'; }
    [[ "$(require_uefi_layout)" == 'UEFI mode detected; EFI System Partition mounted at /boot/efi.' ]]

    uefi_mode_active() { return 1; }
    if output="$(require_uefi_layout 2>&1)"; then
        printf 'FAIL: Legacy boot was accepted\n' >&2
        exit 1
    fi
    [[ "$output" == *'requires Debian to be booted in UEFI mode'* ]]

    uefi_mode_active() { return 0; }
    efi_system_partition() { return 1; }
    if output="$(require_uefi_layout 2>&1)"; then
        printf 'FAIL: missing ESP was accepted\n' >&2
        exit 1
    fi
    [[ "$output" == *'No mounted FAT EFI System Partition'* ]]

    FAILURES=()
    grub_update_command_available() { return 0; }
    verify_grub_theme() { return 0; }
    sudo() { [[ "$*" == 'update-grub' ]]; }
    refresh_grub_menu
    [[ "${#FAILURES[@]}" == 0 ]]

    sudo() { return 1; }
    refresh_grub_menu
    [[ "${FAILURES[0]}" == 'Refresh the GRUB menu with update-grub' ]]
    FAILURES=()
    sudo() { [[ "$*" == 'update-grub' ]]; }
    verify_grub_theme() { return 1; }
    refresh_grub_menu
    [[ "${FAILURES[0]}" == 'Generated GRUB configuration did not enable the Catppuccin graphical menu' ]]
    printf 'PASS: UEFI/ESP preflight and GRUB menu refresh guards\n'
)

(
    source "$ROOT/lib/configure-grub.sh"
    work="$(mktemp -d)"
    trap 'rm -rf -- "$work"' EXIT
    GRUB_TERMINAL=console
    GRUB_TIMEOUT_STYLE=hidden
    source "$ROOT/system/default/grub.d/zz-myconfig-catppuccin.cfg"
    [[ -z "$GRUB_TERMINAL" && "$GRUB_TERMINAL_OUTPUT" == gfxterm && "$GRUB_TIMEOUT_STYLE" == menu && "$GRUB_TIMEOUT" == 5 ]]
    sudo() { if [[ "$1" == grub-script-check ]]; then return 0; else "$@"; fi; }
    printf 'terminal_output gfxterm\nset timeout_style=menu\nset theme=($root)/grub/themes/catppuccin-macchiato-grub-theme/theme.txt\n' >"$work/grub.cfg"
    verify_grub_theme "$work/grub.cfg"
    printf 'terminal_output console\n' >"$work/grub.cfg"
    if verify_grub_theme "$work/grub.cfg"; then printf 'FAIL: unthemed GRUB menu passed validation\n' >&2; exit 1; fi
    printf 'PASS: console/hidden-menu overrides and generated theme verification\n'
)
