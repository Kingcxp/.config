#!/usr/bin/env bash
# Focused Waybar font/style/tray repair; also refreshes Fcitx and the network applet.
# shellcheck disable=SC1091
set -Eeuo pipefail
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lib/install-appearance.sh"
work_dir=""
fcitx_stopped=false
current_step='check execution environment'
cleanup() {
    local repair_status=$?
    if (( repair_status )); then
        printf 'Repair failed during "%s" (exit %s). Log: %s/repair-waybar.log\n' "$current_step" "$repair_status" "$STATE_DIR" >&2
    fi
    if [[ "$fcitx_stopped" == true ]] && ! pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then
        nohup fcitx5 -d >>"$STATE_DIR/fcitx5-tray.log" 2>&1 </dev/null || true
    fi
    if [[ -n "$work_dir" ]]; then rm -rf -- "$work_dir"; fi
}
trap cleanup EXIT
[[ "$EUID" -ne 0 ]] || die 'Run as your normal user, without sudo.'
[[ "$(uname -s)" == Linux ]] || die 'Run on the installed Debian system.'
[[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] || die 'This profile requires ~/.config.'
mkdir -p "$STATE_DIR"
exec > >(tee -a "$STATE_DIR/repair-waybar.log") 2>&1
current_step='check Debian desktop dependencies'
missing_packages=()
for package in libglib2.0-bin dconf-cli dconf-gsettings-backend gsettings-desktop-schemas; do
    if ! desktop_installed "$package"; then missing_packages+=("$package"); fi
done
if (( ${#missing_packages[@]} )); then
    sudo apt-get update -o APT::Update::Error-Mode=any
    sudo apt-get install --no-remove -y "${missing_packages[@]}"
fi
current_step='deploy GTK and Waybar configuration'
# Older GTK config files can replace the original symlink. Repair both the
# settings.ini entry point and dconf, backing up any independent files first.
for gtk_version in 3 4; do
    backup_and_link "$PROFILE_DIR/.config/gtk-$gtk_version.0/settings.ini" "$HOME/.config/gtk-$gtk_version.0/settings.ini"
done
link_tree "$PROFILE_DIR/.config/waybar" "$HOME/.config/waybar"
backup_and_link "$PROFILE_DIR/.local/bin/waybar-start.sh" "$HOME/.local/bin/waybar-start.sh"
backup_and_link "$PROFILE_DIR/.local/bin/waybar-hyprland.py" "$HOME/.local/bin/waybar-hyprland.py"
backup_and_link "$PROFILE_DIR/.local/bin/desktop-session-start.sh" "$HOME/.local/bin/desktop-session-start.sh"
install_tray_icon_theme
current_step='persist the Debian icon theme'
# The real SNI tray loads image pixels, so CSS color alone cannot fix its icons.
# Update only the icon setting; leave the user's other desktop preferences alone.
bash "$SCRIPT_DIR/lib/user-appearance.sh" "$STATE_DIR" icons
current_step='check Waybar fonts'
fc-cache -f
if ! python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc" --quiet; then
    sudo -v
    work_dir="$(mktemp -d)"
    ensure_desktop_nerd_font "$work_dir" "$SCRIPT_DIR"
fi
python3 "$SCRIPT_DIR/lib/check-waybar-fonts.py" "$HOME/.config/waybar/config.jsonc"
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    current_step='restart Fcitx'
    # Fcitx owns its text pixmaps and caches them. Restarting only Waybar never
    # refreshes those pixels. Exit before deploying the config so an old daemon
    # cannot save its previous settings over the newly linked file on shutdown.
    previous_im=''
    if pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then
        previous_im="$(fcitx5-remote -n 2>/dev/null || true)"
        fcitx5-remote -e
        for _ in {1..50}; do
            if ! pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then break; fi
            sleep 0.1
        done
        if pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then die 'Fcitx did not exit; no second instance was started.'; fi
        fcitx_stopped=true
    fi
    backup_and_link "$PROFILE_DIR/.config/fcitx5/conf/classicui.conf" "$HOME/.config/fcitx5/conf/classicui.conf"
    nohup fcitx5 -d >"$STATE_DIR/fcitx5-tray.log" 2>&1 </dev/null
    # The daemon forks before it owns its bus name. Calling fcitx5-remote now
    # would D-Bus-activate another copy. Query the bus itself until it is ready.
    fcitx_ready=false
    for _ in {1..50}; do
        if /usr/bin/gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner org.fcitx.Fcitx5 | grep -Fxq '(true,)'; then
            fcitx_ready=true
            break
        fi
        sleep 0.1
    done
    [[ "$fcitx_ready" == true ]] || die "Fcitx did not acquire its session bus name; inspect $STATE_DIR/fcitx5-tray.log"
    fcitx_stopped=false
    if [[ -n "$previous_im" ]]; then fcitx5-remote -s "$previous_im" || true; fi
    current_step='restart Waybar'
    bash "$HOME/.local/bin/waybar-start.sh" --restart
    current_step='restart the network applet'
    # Restart the UI applet only; NetworkManager and the Wi-Fi connection stay up.
    mapfile -t applet_pids < <(pgrep -u "$(id -u)" -x nm-applet || true)
    if (( ${#applet_pids[@]} )); then kill -- "${applet_pids[@]}"; fi
    for _ in {1..50}; do
        if ! pgrep -u "$(id -u)" -x nm-applet >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -u "$(id -u)" -x nm-applet >/dev/null; then die 'The network applet did not exit; no second instance was started.'; fi
    nohup env -u GTK_USE_PORTAL GDK_BACKEND=wayland GSETTINGS_BACKEND=dconf \
        GSETTINGS_SCHEMA_DIR=/usr/share/glib-2.0/schemas \
        nm-applet --indicator >"$STATE_DIR/nm-applet-tray.log" 2>&1 </dev/null &
    sleep 1
    current_step='inspect live icon sources'
    if ! /usr/bin/python3 "$SCRIPT_DIR/lib/check-panel-icon-sources.py"; then
        printf 'WARNING: configuration was deployed and apps restarted, but live icon diagnostics were unavailable. See %s/repair-waybar.log\n' "$STATE_DIR" >&2
    fi
else
    backup_and_link "$PROFILE_DIR/.config/fcitx5/conf/classicui.conf" "$HOME/.config/fcitx5/conf/classicui.conf"
    printf 'Waybar configuration and light tray icons updated. Log in to Hyprland to load them.\n'
fi
