#!/usr/bin/env bash
# Pinned Catppuccin assets shared by the Debian desktop and UEFI GRUB profile.

CATPPUCCIN_GTK_VERSION=v1.0.3
CATPPUCCIN_GTK_URL='https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-macchiato-lavender-standard%2Bdefault.zip'
CATPPUCCIN_GTK_SHA256=b36a0a26440f23570780cc379e2922c33e84cf88dfecd31bd7603323f4fb43b0
CATPPUCCIN_CURSORS_VERSION=v2.0.0
CATPPUCCIN_CURSORS_URL='https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-macchiato-lavender-cursors.zip'
CATPPUCCIN_CURSORS_SHA256=6f5a5f71ab0ca9ed088dca1167b7fd8b4921c16234fc073d15fce1c54965eeae
CATPPUCCIN_KVANTUM_REV=71105d224fef95dd023691303477ce3eea487457
CATPPUCCIN_KVANTUM_SHA256=f2bd573f8d7500c65fd69e1629b3bcf3eba3468124b81f1d12d54b2f5dda1a0c
CATPPUCCIN_FCITX5_REV=393845cf3ed0e0000bfe57fe1b9ad75748e2547f
CATPPUCCIN_FCITX5_SHA256=8cdb90b3618d56c36075ff88ed6724aa4baba6eb99eafe60df1664fbe63905f6
CATPPUCCIN_GRUB_REV=0a37ab19f654e77129b409fed371891c01ffd0b9
CATPPUCCIN_GRUB_SHA256=285a2f1942d9a7aaaa61d53fbf8eaea40c1bb1a2f5ed662b8355bf9b0499116b

theme_root_path() {
    local path="$1" root="${THEME_INSTALL_ROOT:-/}"
    if [[ "$root" == / ]]; then printf '%s\n' "$path"; else printf '%s%s\n' "${root%/}" "$path"; fi
}

theme_run() {
    if [[ "${THEME_INSTALL_ROOT:-/}" == / ]]; then sudo "$@"; else "$@"; fi
}

verify_theme_archive() {
    local archive="$1" expected="$2"
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status
}

theme_tree_is_current() {
    local target version path marker
    target="$1"; version="$2"
    path="$(theme_root_path "$target")"
    marker="$path/.myconfig-managed"
    theme_run test -f "$marker" || return 1
    [[ "$(theme_run cat -- "$marker")" == "$version" ]]
}

install_managed_theme_tree() {
    local source="$1" target="$2" version="$3" name="$4"
    local destination stage backup marker_root marker backup_mode=0700
    [[ -d "$source" ]] || return 1
    if theme_tree_is_current "$target" "$version"; then
        printf 'Catppuccin theme already installed: %s (%s)\n' "$name" "$version"
        return 0
    fi

    destination="$(theme_root_path "$target")"
    stage="${destination}.myconfig-staging-$$"
    marker_root="$(theme_root_path /var/backups/myconfig-debian/themes)"
    [[ "${THEME_INSTALL_ROOT:-/}" == / ]] || backup_mode=0755
    theme_run install -d -m 0755 "$(dirname -- "$destination")" || return 1
    if theme_run test -e "$stage"; then
        printf 'Refusing to overwrite unfinished theme staging path: %s\n' "$stage" >&2
        return 1
    fi
    theme_run install -d -m 0755 "$stage" || return 1
    if ! theme_run cp -a "$source/." "$stage/"; then
        theme_run rm -rf -- "$stage"
        return 1
    fi

    if theme_run test -e "$destination" || theme_run test -L "$destination"; then
        if ! theme_run install -d -m "$backup_mode" "$marker_root"; then
            theme_run rm -rf -- "$stage"
            return 1
        fi
        backup="$marker_root/$name-$(date +%Y%m%d-%H%M%S)-$$"
        if ! theme_run mv -- "$destination" "$backup"; then
            theme_run rm -rf -- "$stage"
            return 1
        fi
        printf 'Backed up existing theme %s to %s\n' "$destination" "$backup"
    fi
    if ! theme_run mv -- "$stage" "$destination"; then
        if [[ -n "${backup:-}" ]] && ! theme_run test -e "$destination"; then
            theme_run mv -- "$backup" "$destination" || true
        fi
        theme_run rm -rf -- "$stage"
        return 1
    fi
    marker="$destination/.myconfig-managed"
    printf '%s\n' "$version" >"$source/.myconfig-managed"
    theme_run install -m 0644 "$source/.myconfig-managed" "$marker" || return 1
    printf 'Installed Catppuccin theme: %s (%s)\n' "$name" "$version"
}

download_theme_archive() {
    local url="$1" expected="$2" archive="$3"
    curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 "$url" -o "$archive" || return 1
    verify_theme_archive "$archive" "$expected"
}

install_catppuccin_zip_theme() {
    local work="$1" name="$2" version="$3" url="$4" sha="$5"
    local archive_name="$6" source_dir="$7" required_file="$8" target="$9"
    local destination extract archive
    if theme_tree_is_current "$target" "$version"; then
        printf 'Catppuccin theme already installed: %s (%s)\n' "$name" "$version"
        return 0
    fi
    extract="$work/$name"
    archive="$work/$archive_name"
    mkdir -p "$extract"
    download_theme_archive "$url" "$sha" "$archive" || return 1
    unzip -q -o "$archive" -d "$extract" || return 1
    destination="$extract/$source_dir"
    [[ -s "$destination/$required_file" ]] || return 1
    install_managed_theme_tree "$destination" "$target" "$version" "$name"
}

install_catppuccin_tar_theme() {
    local work="$1" name="$2" version="$3" url="$4" sha="$5"
    local archive_name="$6" source_dir="$7" required_file="$8" target="$9"
    local destination extract archive
    if theme_tree_is_current "$target" "$version"; then
        printf 'Catppuccin theme already installed: %s (%s)\n' "$name" "$version"
        return 0
    fi
    extract="$work/$name"
    archive="$work/$archive_name"
    mkdir -p "$extract"
    download_theme_archive "$url" "$sha" "$archive" || return 1
    tar -xzf "$archive" --strip-components=1 -C "$extract" || return 1
    destination="$extract/$source_dir"
    [[ -s "$destination/$required_file" ]] || return 1
    install_managed_theme_tree "$destination" "$target" "$version" "$name"
}

configure_catppuccin_appearance() {
    local work="$1" source="$2" grub_version="nix-catppuccin-$CATPPUCCIN_GRUB_REV"
    local THEME_INSTALL_ROOT="${3:-/}"
    mkdir -p "$work"

    if ! install_catppuccin_zip_theme "$work" gtk "$CATPPUCCIN_GTK_VERSION" \
        "$CATPPUCCIN_GTK_URL" "$CATPPUCCIN_GTK_SHA256" gtk.zip \
        'catppuccin-macchiato-lavender-standard+default' gtk-3.0/gtk.css \
        /usr/local/share/themes/catppuccin-macchiato-lavender-standard; then
        setup_failure 'Install and verify the Catppuccin GTK Macchiato/Lavender theme'
    fi
    if ! install_catppuccin_zip_theme "$work" cursors "$CATPPUCCIN_CURSORS_VERSION" \
        "$CATPPUCCIN_CURSORS_URL" "$CATPPUCCIN_CURSORS_SHA256" cursors.zip \
        catppuccin-macchiato-lavender-cursors index.theme \
        /usr/local/share/icons/catppuccin-macchiato-lavender-cursors; then
        setup_failure 'Install and verify the Catppuccin Macchiato/Lavender cursor theme'
    fi
    if ! install_catppuccin_tar_theme "$work" kvantum "$CATPPUCCIN_KVANTUM_REV" \
        "https://codeload.github.com/catppuccin/Kvantum/tar.gz/$CATPPUCCIN_KVANTUM_REV" \
        "$CATPPUCCIN_KVANTUM_SHA256" kvantum.tar.gz \
        themes/catppuccin-macchiato-lavender catppuccin-macchiato-lavender.kvconfig \
        /usr/local/share/Kvantum/catppuccin-macchiato-lavender; then
        setup_failure 'Install and verify the Catppuccin Macchiato/Lavender Kvantum theme'
    fi
    if ! install_catppuccin_tar_theme "$work" fcitx5 "$CATPPUCCIN_FCITX5_REV" \
        "https://codeload.github.com/catppuccin/fcitx5/tar.gz/$CATPPUCCIN_FCITX5_REV" \
        "$CATPPUCCIN_FCITX5_SHA256" fcitx5.tar.gz \
        src/catppuccin-macchiato-lavender theme.conf \
        /usr/local/share/fcitx5/themes/catppuccin-macchiato-lavender; then
        setup_failure 'Install and verify the Catppuccin Macchiato/Lavender Fcitx5 theme'
    fi
    if install_catppuccin_tar_theme "$work" grub "$grub_version" \
        "https://codeload.github.com/catppuccin/grub/tar.gz/$CATPPUCCIN_GRUB_REV" \
        "$CATPPUCCIN_GRUB_SHA256" grub.tar.gz \
        src/catppuccin-macchiato-grub-theme theme.txt \
        /usr/local/share/grub/themes/catppuccin-macchiato-grub-theme; then
        for required in font.pf2 background.png; do
            if ! theme_run test -s "$(theme_root_path "/usr/local/share/grub/themes/catppuccin-macchiato-grub-theme/$required")"; then
                setup_failure "Catppuccin GRUB theme is missing $required"
                return
            fi
        done
        if ! write_system_file "$source/system/default/grub.d/50-myconfig-catppuccin.cfg" \
            /etc/default/grub.d/50-myconfig-catppuccin.cfg; then
            setup_failure 'Configure the Catppuccin Macchiato/Lavender GRUB theme'
        fi
    else
        setup_failure 'Install and verify the Catppuccin Macchiato GRUB theme'
    fi
}
