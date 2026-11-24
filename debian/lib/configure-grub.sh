#!/usr/bin/env bash
# Used by both initial installation and the unified desktop refresh.

# Debian puts update-grub in /usr/sbin, which is often absent from a regular
# user's PATH. Check the installed executable, not the invoking shell's PATH.
grub_update_command_available() { [[ -x /usr/sbin/update-grub ]]; }

verify_grub_theme() {
    local config="${1:-/boot/grub/grub.cfg}"
    sudo /usr/bin/grub-script-check "$config" || return 1
    sudo grep -Eq '^[[:space:]]*set theme=.*catppuccin-macchiato-grub-theme/theme\.txt' "$config" || {
        printf 'Generated GRUB menu has no Catppuccin theme. Check GRUB_TERMINAL and later /etc/default/grub.d snippets.\n' >&2
        return 1
    }
    sudo grep -Eq '^[[:space:]]*terminal_output[[:space:]]+gfxterm([[:space:]]|$)' "$config" || return 1
    sudo grep -Eq '^[[:space:]]*set timeout_style=menu' "$config" || return 1
}

refresh_grub_menu() {
    if ! grub_update_command_available; then
        setup_failure 'Missing or non-executable /usr/sbin/update-grub (provided by Debian package grub2-common)'
    elif ! sudo /usr/sbin/update-grub; then
        setup_failure 'Refresh the GRUB menu with update-grub'
    elif ! verify_grub_theme /boot/grub/grub.cfg; then
        setup_failure 'Generated GRUB configuration did not enable the Catppuccin graphical menu'
    else
        printf 'Verified Catppuccin theme and graphical menu in /boot/grub/grub.cfg.\n'
    fi
}
