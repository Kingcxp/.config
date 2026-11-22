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
    sudo() { [[ "$*" == 'update-grub' ]]; }
    refresh_grub_menu
    [[ "${#FAILURES[@]}" == 0 ]]

    sudo() { return 1; }
    refresh_grub_menu
    [[ "${FAILURES[0]}" == 'Refresh the GRUB menu with update-grub' ]]
    printf 'PASS: UEFI/ESP preflight and GRUB menu refresh guards\n'
)
