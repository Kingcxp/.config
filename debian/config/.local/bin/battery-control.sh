#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE_SYS=/sys/firmware/acpi/platform_profile
PROFILE_CHOICES=/sys/firmware/acpi/platform_profile_choices
THRESHOLD_NAME=charge_control_end_threshold

notify() {
    notify-send -u normal -i battery-good "电池" "$1"
}

write_sysfs() {
    local value="$1" path="$2"
    if [[ -w "$path" ]]; then
        printf '%s\n' "$value" > "$path"
    else
        printf '%s\n' "$value" | pkexec /usr/bin/tee "$path" >/dev/null
    fi
}

find_battery() {
    local battery
    for battery in /sys/class/power_supply/BAT*; do
        if [[ -d "$battery" && -r "$battery/capacity" ]]; then
            printf '%s\n' "$battery"
            return 0
        fi
    done
    return 1
}

find_conservation_mode() {
    find /sys/devices -type f -name conservation_mode -print -quit 2>/dev/null || true
}

profile_label() {
    case "$1" in
        low-power) printf '省电' ;;
        balanced) printf '平衡' ;;
        performance) printf '性能' ;;
        *) printf '%s' "$1" ;;
    esac
}

apply_profile() {
    local profile="$1"
    write_sysfs "$profile" "$PROFILE_SYS"
    notify "电源策略已切换为 $(profile_label "$profile")"
}

optimize_now() {
    local powertop
    powertop="$(command -v powertop)"
    pkexec "$powertop" --auto-tune
    notify "powertop 一键优化完成"
}

strategy_menu() {
    local current choice profile
    local -a profiles=()
    if [[ -r "$PROFILE_CHOICES" ]]; then
        read -r -a profiles < "$PROFILE_CHOICES"
    fi

    current="$(cat "$PROFILE_SYS" 2>/dev/null || printf 'unknown')"
    local -a options=()
    for profile in "${profiles[@]}"; do
        options+=("$(profile_label "$profile") ($profile)")
    done
    options+=("一键 powertop 优化")

    choice="$(printf '%s\n' "${options[@]}" | wofi --dmenu --prompt "电源策略 (当前: $(profile_label "$current"))")" || return 0
    case "$choice" in
        *powertop*) optimize_now ;;
        "") return 0 ;;
        *)
            profile="${choice##* (}"
            profile="${profile%)}"
            apply_profile "$profile"
            ;;
    esac
}

battery_status_text() {
    local battery mode value
    battery="$(find_battery)" || {
        printf '未检测到电池\n'
        return 1
    }
    mode="$(find_conservation_mode)"
    value="关闭"
    if [[ -n "$mode" && "$(cat "$mode" 2>/dev/null || true)" == 1 ]]; then
        value="开启"
    fi
    printf '当前电量 %s%% (%s) | 养护模式: %s\n' \
        "$(cat "$battery/capacity")" "$(cat "$battery/status" 2>/dev/null || printf 'unknown')" "$value"
}

charge_control() {
    local battery threshold current selected mode choice candidate
    battery="$(find_battery)" || {
        notify "未检测到电池设备"
        return 1
    }

    threshold=""
    for candidate in /sys/class/power_supply/BAT*/"$THRESHOLD_NAME"; do
        if [[ -e "$candidate" ]]; then
            threshold="$candidate"
            break
        fi
    done

    if [[ -n "$threshold" ]]; then
        current="$(cat "$threshold")"
        selected="$(zenity --scale --text='最大充电量 (%)' --min-value=50 --max-value=100 --step=5 --value="$current" 2>/dev/null)" || return 0
        [[ -n "$selected" ]] || return 0
        selected="$(printf '%.0f' "$selected")"
        write_sysfs "$selected" "$threshold"
        notify "最大充电量已设为 ${selected}%"
        return 0
    fi

    mode="$(find_conservation_mode)"
    if [[ -z "$mode" ]]; then
        notify "当前固件没有暴露充电上限或电池养护接口"
        return 1
    fi

    current="$(cat "$mode" 2>/dev/null || printf '0')"
    local current_label='关闭'
    [[ "$current" == 1 ]] && current_label='开启（约 80% 上限）'
    choice="$(printf '开启电池养护（约 80%% 上限）\n关闭电池养护（充至 100%%）' | wofi --dmenu --prompt "电池保护 (当前: $current_label)")" || return 0
    case "$choice" in
        开启*) write_sysfs 1 "$mode"; notify '电池养护已开启' ;;
        关闭*) write_sysfs 0 "$mode"; notify '电池养护已关闭' ;;
    esac
}

case "${1:-strategy}" in
    strategy) strategy_menu ;;
    charge) charge_control ;;
    optimize) optimize_now ;;
    status) battery_status_text ;;
    *) printf 'Usage: %s [strategy|charge|optimize|status]\n' "$0" >&2; exit 2 ;;
esac
