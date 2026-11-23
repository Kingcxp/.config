#!/usr/bin/env bash
# Used by both full installation and the focused desktop repair.

grub_update_command_available() { command -v update-grub >/dev/null 2>&1; }

verify_grub_theme() {
    local config="${1:-/boot/grub/grub.cfg}"
    sudo grub-script-check "$config" || return 1
    sudo grep -Eq '^[[:space:]]*set theme=.*catppuccin-macchiato-grub-theme/theme\.txt' "$config" || {
        printf 'Generated GRUB menu has no Catppuccin theme. Check GRUB_TERMINAL and later /etc/default/grub.d snippets.\n' >&2
        return 1
    }
    sudo grep -Eq '^[[:space:]]*terminal_output[[:space:]]+gfxterm([[:space:]]|$)' "$config" || return 1
    sudo grep -Eq '^[[:space:]]*set timeout_style=menu' "$config" || return 1
}

refresh_grub_menu() {
    if ! grub_update_command_available; then
        setup_failure 'GRUB tools are missing after APT installation'
    elif ! sudo update-grub; then
        setup_failure 'Refresh the GRUB menu with update-grub'
    elif ! verify_grub_theme /boot/grub/grub.cfg; then
        setup_failure 'Generated GRUB configuration did not enable the Catppuccin graphical menu'
    else
        printf 'Verified Catppuccin theme and graphical menu in /boot/grub/grub.cfg.\n'
    fi
}
