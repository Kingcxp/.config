#!/usr/bin/env bash
# Functions used by install.sh --refresh; this file performs no work when sourced.

REFRESH_WORK_DIR=""
REFRESH_FCITX_STOPPED=false
REFRESH_STEP="starting"

refresh_cleanup() {
    local status=$?
    if (( status )); then
        printf 'Desktop update stopped during "%s" (exit %s). Log: %s/install-refresh.log\n' \
            "$REFRESH_STEP" "$status" "$STATE_DIR" >&2
    fi
    if [[ "$REFRESH_FCITX_STOPPED" == true ]] && ! pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then
        nohup fcitx5 -d >>"$STATE_DIR/fcitx5-tray.log" 2>&1 </dev/null || true
    fi
    if [[ -n "$REFRESH_WORK_DIR" ]]; then rm -rf -- "$REFRESH_WORK_DIR"; fi
}

refresh_usb_applet() {
    REFRESH_STEP='restart the USB tray applet'
    local -a pids=()
    mapfile -t pids < <(pgrep -u "$(id -u)" -x udiskie || true)
    if (( ${#pids[@]} )); then kill -- "${pids[@]}"; fi
    for _ in {1..50}; do
        if ! pgrep -u "$(id -u)" -x udiskie >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -u "$(id -u)" -x udiskie >/dev/null; then die 'udiskie did not exit; a second instance was not started.'; fi
    nohup env -u GTK_USE_PORTAL GDK_BACKEND=wayland GSETTINGS_BACKEND=dconf \
        GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas \
        udiskie --tray >"$STATE_DIR/udiskie-tray.log" 2>&1 </dev/null &
    local applet_pid=$!
    sleep 1
    if ! kill -0 "$applet_pid" 2>/dev/null; then
        cat "$STATE_DIR/udiskie-tray.log" >&2
        die 'The USB tray applet could not start.'
    fi
}

configure_waybar_and_tray() {
    local package previous_im='' fcitx_ready=false
    local -a missing=() pids=()
    REFRESH_STEP='check the Debian desktop settings tools'
    for package in libglib2.0-bin dconf-cli dconf-gsettings-backend gsettings-desktop-schemas; do
        if ! desktop_installed "$package"; then missing+=("$package"); fi
    done
    if (( ${#missing[@]} )); then
        sudo apt-get update -o APT::Update::Error-Mode=any
        sudo apt-get install --no-remove -y "${missing[@]}"
    fi

    REFRESH_STEP='deploy GTK and Waybar settings'
    for package in 3 4; do
        backup_and_link "$PROFILE_DIR/.config/gtk-$package.0/settings.ini" "$HOME/.config/gtk-$package.0/settings.ini"
    done
    link_tree "$PROFILE_DIR/.config/waybar" "$HOME/.config/waybar"
    backup_and_link "$PROFILE_DIR/.local/bin/waybar-start.sh" "$HOME/.local/bin/waybar-start.sh"
    backup_and_link "$PROFILE_DIR/.local/bin/waybar-hyprland.py" "$HOME/.local/bin/waybar-hyprland.py"
    backup_and_link "$PROFILE_DIR/.local/bin/desktop-session-start.sh" "$HOME/.local/bin/desktop-session-start.sh"
    install_tray_icon_theme
    bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR" icons

    REFRESH_STEP='check Waybar fonts'
    fc-cache -f
    if ! python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc" --quiet; then
        sudo -v
        REFRESH_WORK_DIR="$(mktemp -d)"
        ensure_desktop_nerd_font "$REFRESH_WORK_DIR" "$SCRIPT_DIR"
    fi
    python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc"

    if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        printf 'Waybar, Fcitx, network, and USB tray settings are deployed; Hyprland will load them at the next login.\n'
        return 0
    fi

    REFRESH_STEP='restart Fcitx with the light input icon'
    if pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then
        previous_im="$(fcitx5-remote -n 2>/dev/null || true)"
        fcitx5-remote -e
        for _ in {1..50}; do
            if ! pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then break; fi
            sleep 0.1
        done
        if pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then die 'Fcitx did not exit; a second instance was not started.'; fi
        REFRESH_FCITX_STOPPED=true
    fi
    backup_and_link "$PROFILE_DIR/.config/fcitx5/conf/classicui.conf" "$HOME/.config/fcitx5/conf/classicui.conf"
    nohup fcitx5 -d >"$STATE_DIR/fcitx5-tray.log" 2>&1 </dev/null
    for _ in {1..50}; do
        if /usr/bin/gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner org.fcitx.Fcitx5 | grep -Fxq '(true,)'; then
            fcitx_ready=true
            break
        fi
        sleep 0.1
    done
    [[ "$fcitx_ready" == true ]] || die "Fcitx did not acquire its session bus name; inspect $STATE_DIR/fcitx5-tray.log"
    REFRESH_FCITX_STOPPED=false
    if [[ -n "$previous_im" ]]; then fcitx5-remote -s "$previous_im" || true; fi

    REFRESH_STEP='restart Waybar'
    bash "$HOME/.local/bin/waybar-start.sh" --restart
    REFRESH_STEP='restart the network tray applet'
    mapfile -t pids < <(pgrep -u "$(id -u)" -x nm-applet || true)
    if (( ${#pids[@]} )); then kill -- "${pids[@]}"; fi
    for _ in {1..50}; do
        if ! pgrep -u "$(id -u)" -x nm-applet >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -u "$(id -u)" -x nm-applet >/dev/null; then die 'The network applet did not exit; a second instance was not started.'; fi
    nohup env -u GTK_USE_PORTAL GDK_BACKEND=wayland GSETTINGS_BACKEND=dconf \
        GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas \
        nm-applet --indicator >"$STATE_DIR/nm-applet-tray.log" 2>&1 </dev/null &
    sleep 1
    refresh_usb_applet
    REFRESH_STEP='inspect the live icon sources'
    if ! /usr/bin/python3 "$SCRIPT_DIR/lib/check-panel-icon-sources.py"; then
        printf 'WARNING: settings were deployed and tray apps restarted, but the optional live icon report is unavailable. See %s/install-refresh.log\n' "$STATE_DIR" >&2
    fi
}

configure_existing_desktop() {
    [[ "$EUID" -ne 0 ]] || die 'Run as your regular account, without sudo.'
    [[ "$(uname -s)" == Linux ]] || die 'Run this installer on Debian Linux.'
    [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'This profile requires ~/.config.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == debian && "${VERSION_CODENAME:-}" == trixie ]] || die 'This mode requires Debian 13 Trixie.'
    sudo -v
    mkdir -p "$STATE_DIR"
    REFRESH_WORK_DIR="$(mktemp -d)"
    REFRESH_STEP='prepare the desktop update'
    FAILURES=()
    trap refresh_cleanup EXIT
    exec > >(tee -a "$STATE_DIR/install-refresh.log") 2>&1

    local package need_guiutils=false
    local -a missing=()
    for package in curl ca-certificates unzip xz-utils python3 git fish fontconfig fonts-noto-cjk fonts-font-awesome \
        papirus-icon-theme dconf-cli gsettings-desktop-schemas libglib2.0-bin dbus-user-session qt5ct qt6ct \
        qt5-style-kvantum qt6-style-kvantum grub-common grub2-common \
        qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
        qml6-module-qtquick-window qml6-module-qtquick-templates qml6-module-qtqml-models \
        qml6-module-qtqml-workerscript libqt6svg6 qt6-svg-plugins; do
        if ! desktop_installed "$package"; then missing+=("$package"); fi
    done
    if ! desktop_installed hyprland-guiutils; then need_guiutils=true; fi
    if (( ${#missing[@]} )) || [[ "$need_guiutils" == true ]]; then
        REFRESH_STEP='install missing desktop prerequisites'
        sudo apt-get update -o APT::Update::Error-Mode=any
    fi
    if (( ${#missing[@]} )); then sudo apt-get install --no-remove -y "${missing[@]}"; fi
    if [[ "$need_guiutils" == true ]]; then sudo apt-get install --no-remove -y -t trixie-backports hyprland-guiutils; fi

    REFRESH_STEP='install the Catppuccin themes'
    configure_catppuccin_appearance "$REFRESH_WORK_DIR" "$SCRIPT_DIR"
    REFRESH_STEP='refresh the GRUB menu'
    refresh_grub_menu
    if [[ -d /sys/firmware/efi ]] && command -v efibootmgr >/dev/null; then
        printf '\nCurrent UEFI boot entries (read-only):\n'
        sudo efibootmgr -v || true
    fi
    REFRESH_STEP='set the Catppuccin login screen'
    desktop_configure_greeter || setup_failure 'Apply the Catppuccin SDDM theme and disable the virtual keyboard'
    desktop_system_file "$SCRIPT_DIR/session/myconfig-hyprland" /usr/local/bin/myconfig-hyprland 0755 \
        || setup_failure 'Update the Hyprland session wrapper'

    REFRESH_STEP='deploy the complete user configuration'
    deploy_user_configuration
    install_tmux_plugins
    bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR" || setup_failure 'Apply GTK and desktop appearance'
    if command -v xdg-user-dirs-update >/dev/null; then xdg-user-dirs-update; fi
    fc-cache -f || setup_failure 'Refresh the user font cache'
    fc-match 'JetBrainsMono Nerd Font'
    fc-match 'Noto Sans CJK SC'
    configure_waybar_and_tray

    REFRESH_STEP='verify the Hyprland configuration'
    if command -v Hyprland >/dev/null; then
        timeout 30s Hyprland --verify-config --config "$HOME/.config/hypr/hyprland.lua" \
            || setup_failure 'Validate the Hyprland configuration'
    else
        setup_failure 'Hyprland is not installed'
    fi
    if (( ${#FAILURES[@]} )); then
        printf '%s\n' "${FAILURES[@]}" >"$STATE_DIR/configuration-failures.txt"
        printf '\nDesktop update incomplete. See %s/install-refresh.log and configuration-failures.txt.\n' "$STATE_DIR" >&2
        return 1
    fi
    rm -f -- "$STATE_DIR/configuration-failures.txt"
    printf '\nDesktop configuration is up to date. Reboot to load the login screen/GRUB changes; the active Waybar and tray were refreshed now.\n'
    printf 'No KDE packages were removed and the software manifest was not reinstalled. Backups are under %s and /var/backups/myconfig-debian/.\n' "$STATE_DIR"
}
