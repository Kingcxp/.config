#!/usr/bin/env bash
set -Eeuo pipefail
config_dir="$HOME/.config/waybar"
compatibility="$HOME/.local/bin/waybar-hyprland.py"
export FONTCONFIG_FILE="$config_dir/fontconfig.conf"
for file in config.jsonc style.css fontconfig.conf; do
    [[ -r "$config_dir/$file" ]] || { printf 'Missing Waybar file: %s/%s\n' "$config_dir" "$file" >&2; exit 1; }
done
[[ -r "$compatibility" ]] || { printf 'Missing Waybar IPC helper: %s\n' "$compatibility" >&2; exit 1; }
case "${1:-}" in
    '') exec python3 "$compatibility" --config "$config_dir/config.jsonc" --style "$config_dir/style.css" ;;
    --restart) ;;
    *) printf 'Usage: waybar-start.sh [--restart]\n' >&2; exit 2 ;;
esac
[[ -n "${WAYLAND_DISPLAY:-}" ]] || { printf 'Restart Waybar from your Hyprland desktop.\n' >&2; exit 1; }
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/myconfig-debian"
mkdir -p "$state_dir"
# Terminate only Waybar processes owned by this user, then launch the pinned style.
mapfile -t bar_pids < <(pgrep -u "$(id -u)" -x waybar || true)
if (( ${#bar_pids[@]} )); then kill -- "${bar_pids[@]}" || true; fi
for _ in {1..50}; do
    if ! pgrep -u "$(id -u)" -x waybar >/dev/null; then break; fi
    sleep 0.1
done
if pgrep -u "$(id -u)" -x waybar >/dev/null; then
    printf 'The old Waybar did not exit; a second instance was not started.\n' >&2
    exit 1
fi
nohup python3 "$compatibility" --config "$config_dir/config.jsonc" --style "$config_dir/style.css" \
    >"$state_dir/waybar.log" 2>&1 </dev/null &
bar_pid=$!
for _ in {1..50}; do
    if ! kill -0 "$bar_pid" 2>/dev/null; then
        cat "$state_dir/waybar.log" >&2
        exit 1
    fi
    if grep -q 'Bar configured' "$state_dir/waybar.log"; then
        printf 'Waybar restarted with JetBrainsMono Nerd Font; log: %s/waybar.log\n' "$state_dir"
        exit 0
    fi
    sleep 0.1
done
printf 'Waybar started but did not confirm a configured bar; inspect %s/waybar.log.\n' "$state_dir" >&2
exit 1
