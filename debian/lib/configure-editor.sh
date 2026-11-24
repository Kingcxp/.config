#!/usr/bin/env bash
# Shared editor prerequisites. Importing this file has no installation effects.

EDITOR_BREW_PATH=""
EDITOR_BREW_PREFIX=""

editor_load_path() {
    local prefix="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}" candidate
    if [[ -r "$STATE_DIR/brew-prefix" ]]; then IFS= read -r prefix <"$STATE_DIR/brew-prefix"; fi
    EDITOR_BREW_PATH=""
    for candidate in "$(command -v brew || true)" "$prefix/bin/brew" /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        if [[ -x "$candidate" ]]; then EDITOR_BREW_PATH="$candidate"; break; fi
    done
    if [[ -n "$EDITOR_BREW_PATH" ]]; then prefix="$("$EDITOR_BREW_PATH" --prefix)" || return 1; fi
    [[ "$prefix" == /* && "$prefix" != *[[:space:]]* ]] || return 1
    EDITOR_BREW_PREFIX="$prefix"
    export PATH="$prefix/opt/node@22/bin:$prefix/bin:$prefix/sbin:$HOME/.local/bin:$PATH"
    hash -r
}

editor_check_language_servers() {
    local quiet="${1:-false}" command_name executable missing=false
    for command_name in node vscode-json-language-server vscode-html-language-server vscode-css-language-server; do
        executable="$(command -v "$command_name" || true)"
        if [[ ! -f "$executable" || ! -x "$executable" ]]; then
            missing=true
            if [[ "$quiet" != true ]]; then printf 'Missing editor executable: %s\n' "$command_name" >&2; fi
        fi
    done
    [[ "$missing" == false ]]
}

editor_ensure_language_servers() {
    editor_load_path || return 1
    if [[ -n "$EDITOR_BREW_PATH" ]]; then
        mkdir -p "$STATE_DIR" || return 1
        printf '%s\n' "$EDITOR_BREW_PREFIX" >"$STATE_DIR/brew-prefix" || return 1
    fi
    if editor_check_language_servers true; then
        printf 'JSON/HTML/CSS language servers are available in PATH.\n'
        return 0
    fi
    if [[ -z "$EDITOR_BREW_PATH" ]]; then
        editor_check_language_servers || true
        printf 'Homebrew is unavailable. Run the full installer first, or use an existing Node/npm installation:\n  npm install --global --prefix %q vscode-langservers-extracted\n' "$HOME/.local" >&2
        return 1
    fi
    printf 'Installing the shared JSON/HTML/CSS server package: vscode-langservers-extracted\n'
    HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 "$EDITOR_BREW_PATH" install --formula vscode-langservers-extracted || return 1
    hash -r
    if ! editor_check_language_servers true; then
        # An already installed but unlinked formula may lack the public commands.
        # Do not overwrite binaries owned by another package or the user.
        "$EDITOR_BREW_PATH" link vscode-langservers-extracted || return 1
        hash -r
    fi
    editor_check_language_servers
}

configure_editor_only() {
    [[ "$EUID" -ne 0 ]] || die 'Run as your regular account, without sudo.'
    [[ "$(uname -s)" == Linux ]] || die 'Run this installer on Debian Linux.'
    [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'This profile requires ~/.config.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || die 'This mode requires Debian 13 Trixie.'
    [[ -f "$PROFILE_DIR/.config/nvim/init.lua" ]] || die 'The Neovim profile is missing from this checkout.'
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$STATE_DIR/install-editor.log") 2>&1
    editor_ensure_language_servers
    command -v nvim >/dev/null || die 'Neovim is unavailable; use the full installer to install it.'
    link_tree "$PROFILE_DIR/.config/nvim" "$HOME/.config/nvim"
    link_tree "$PROFILE_DIR/.config/fontconfig" "$HOME/.config/fontconfig"
    link_tree "$PROFILE_DIR/.config/kitty" "$HOME/.config/kitty"
    fc-cache -f
    python3 "$SCRIPT_DIR/lib/check-cjk-fonts.py"
    printf '\nNeovim and terminal fonts configured; close/reopen Kitty and Neovim to load the Chinese font preferences.\n'
    printf 'Let Lazy install the enabled Mason plugins.\n'
    printf 'In Neovim: :LspInfo, :Mason, :LspInstall jsonls (manual alternative).\n'
    if [[ -n "$BACKUP_ROOT" ]]; then printf 'Config backups: %s\n' "$BACKUP_ROOT"; fi
}
