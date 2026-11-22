#!/usr/bin/env bash
# Helpers sourced by install-software.sh; functions run only when explicitly called.

setup_failure() {
    FAILURES+=("$*")
    printf 'SETUP FAILED: %s\n' "$*" >&2
}

system_unit_exists() {
    systemctl list-unit-files --no-legend --no-pager "$1" 2>/dev/null \
        | awk '{ print $1 }' | grep -Fxq "$1"
}

user_unit_exists() {
    systemctl --user list-unit-files --no-legend --no-pager "$1" 2>/dev/null \
        | awk '{ print $1 }' | grep -Fxq "$1"
}

enable_system_unit() {
    local unit="$1"
    if ! system_unit_exists "$unit"; then
        printf 'System unit is not installed; skipping: %s\n' "$unit"
        return 0
    fi
    if ! sudo systemctl enable --now "$unit"; then setup_failure "Enable system service $unit"; fi
}

write_system_file() {
    local source="$1" target="$2" mode="${3:-0644}" backup
    if sudo cmp -s -- "$source" "$target" 2>/dev/null; then return 0; fi
    if sudo test -e "$target" && ! sudo grep -q '^# Managed by myconfig' "$target"; then
        backup="/var/backups/myconfig-debian/system/$(date +%Y%m%d-%H%M%S)-$$"
        sudo install -d -m 0700 "$backup" || return 1
        sudo cp --parents -- "$target" "$backup/" || return 1
    fi
    sudo install -D -m "$mode" "$source" "$target"
}

configure_firewall() {
    local ok=true rule
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        printf 'Skipping UFW activation from an SSH session; rerun locally to apply the laptop firewall policy.\n'
        return 0
    fi
    if ! command -v ufw >/dev/null 2>&1; then
        setup_failure 'UFW is not installed; inbound firewall policy was not applied'
        return
    fi

    sudo ufw default deny incoming || ok=false
    sudo ufw default deny routed || ok=false
    sudo ufw default allow outgoing || ok=false
    sudo ufw allow in on tailscale0 to any port 22 proto tcp || ok=false
    for rule in 53317/tcp 53317/udp 41641/udp 27036/tcp 27037/tcp 27036/udp \
        10400:10401/udp 27031:27035/udp; do
        sudo ufw allow "$rule" || ok=false
    done
    if [[ "$ok" == true ]]; then
        sudo ufw --force enable || ok=false
    fi
    [[ "$ok" == true ]] || setup_failure 'Apply UFW rules matching the NixOS firewall profile'
}

configure_ssh() {
    local work="$WORK_DIR/sshd-config.conf"
    if ! sed "s/@MYCONFIG_USERNAME@/$RUN_USER/g" "$SCRIPT_DIR/system/ssh/00-myconfig.conf" >"$work"; then
        setup_failure 'Prepare the SSH access policy'
        return
    fi
    if ! sudo sshd -t -f "$work"; then
        setup_failure 'Validate the SSH access policy'
        return
    fi
    if ! write_system_file "$work" /etc/ssh/sshd_config.d/00-myconfig.conf; then
        setup_failure 'Install the SSH access policy'
        return
    fi
    if ! sudo sshd -t; then
        setup_failure 'Validate the combined OpenSSH configuration'
        return
    fi
    if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
        printf 'SSH is configured for public keys only. Add a key to ~/.ssh/authorized_keys before using remote login.\n'
    fi
}

configure_bluetooth_experimental() {
    local target=/etc/bluetooth/main.conf work="$WORK_DIR/bluetooth-main.conf"
    if ! sudo test -r "$target" || ! sudo cat "$target" | tee "$work" >/dev/null; then
        setup_failure 'Read the BlueZ configuration to enable the NixOS-matching experimental features'
        return
    fi
    if ! python3 "$SCRIPT_DIR/lib/configure-bluez.py" "$work"; then
        setup_failure 'Prepare the BlueZ experimental feature setting'
        return
    fi
    if ! write_system_file "$work" "$target"; then
        setup_failure 'Enable BlueZ experimental features'
        return
    fi
    printf 'Enabled BlueZ Experimental=true; the setting takes effect when bluetooth.service next starts.\n'
}

add_user_groups() {
    local group current_groups
    local -a missing=()
    current_groups=" $(id -nG "$RUN_USER") "
    for group in networkmanager netdev video render libvirt kvm gamemode; do
        getent group "$group" >/dev/null || continue
        [[ "$current_groups" == *" $group "* ]] || missing+=("$group")
    done
    if (( ${#missing[@]} )); then
        local IFS=,
        sudo usermod -aG "${missing[*]}" "$RUN_USER" || setup_failure "Add $RUN_USER to device, VM, and GameMode groups"
        printf 'Added %s to groups: %s (takes effect after logging in again).\n' "$RUN_USER" "${missing[*]}"
    fi
}

ensure_subid_range() {
    local kind="$1" file="/etc/sub$1" start=100000 end option
    option="--add-sub${kind}ids"
    if awk -F: -v user="$RUN_USER" '$1 == user { found=1 } END { exit !found }' "$file" 2>/dev/null; then
        return 0
    fi
    while :; do
        end=$((start + 65535))
        if ! awk -F: -v first="$start" -v last="$end" \
            '$2 <= last && ($2 + $3 - 1) >= first { found=1 } END { exit !found }' "$file" 2>/dev/null; then
            break
        fi
        start=$((end + 1))
    done
    sudo usermod "$option" "$start-$end" "$RUN_USER"
}

configure_rootless_docker() {
    local docker_preexisting="${1:-false}"
    local setup=/usr/share/docker.io/contrib/dockerd-rootless-setuptool.sh
    local config_dir="$HOME/.config/docker" config_file="$HOME/.config/docker/daemon.json"
    [[ -x /usr/bin/docker ]] || return 0

    if [[ -L "$config_dir" || ( -e "$config_dir" && ! -d "$config_dir" ) ]]; then
        setup_failure "Cannot safely prepare Docker config directory $config_dir"
        return
    fi
    mkdir -p "$config_dir"
    if [[ ! -e "$config_file" && ! -L "$config_file" ]]; then
        install -m 0600 "$SCRIPT_DIR/config/.config/docker/daemon.json" "$config_file"
    elif ! python3 -m json.tool "$config_file" >/dev/null 2>&1; then
        setup_failure "Docker config is not valid JSON; preserved $config_file"
        return
    fi

    if [[ "$docker_preexisting" == false ]]; then
        # Debian starts the rootful daemon when docker.io is first installed.
        sudo systemctl disable --now docker.service docker.socket \
            || setup_failure 'Stop the newly installed rootful Docker service'
    fi

    if [[ ! -f "$HOME/.config/systemd/user/docker.service" ]]; then
        if [[ ! -f "$setup" ]]; then
            setup_failure 'Debian docker.io rootless setup helper is missing'
            return
        fi
        if ! bash "$setup" install; then
            setup_failure 'Install the per-user rootless Docker service'
            return
        fi
    fi

    ensure_subid_range uids || { setup_failure 'Allocate subordinate UID range for rootless Docker'; return; }
    ensure_subid_range gids || { setup_failure 'Allocate subordinate GID range for rootless Docker'; return; }
    if ! write_system_file "$SCRIPT_DIR/system/environment.d/60-docker-rootless.conf" \
        /etc/environment.d/60-docker-rootless.conf; then
        setup_failure 'Install the rootless Docker environment setting'
        return
    fi
    sudo loginctl enable-linger "$RUN_USER" || setup_failure "Enable lingering for $RUN_USER"
    systemctl --user daemon-reload || setup_failure 'Reload the user systemd manager for Docker'
    systemctl --user enable --now docker.service || setup_failure 'Start the rootless Docker user service'
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"
}

configure_camera_module() {
    local source target
    for source in "$SCRIPT_DIR/system/modprobe.d/myconfig-v4l2loopback.conf" \
        "$SCRIPT_DIR/system/modules-load.d/myconfig-v4l2loopback.conf"; do
        target="/etc/${source#"$SCRIPT_DIR/system/"}"
        if ! write_system_file "$source" "$target"; then
            setup_failure "Install camera module configuration $target"
        fi
    done
    if command -v dkms >/dev/null 2>&1; then
        if ! sudo dkms autoinstall; then setup_failure 'Build v4l2loopback for the installed kernel headers'; return; fi
    fi
    if modinfo v4l2loopback >/dev/null 2>&1; then
        if ! sudo modprobe v4l2loopback; then
            printf 'WARNING: OBS virtual camera module could not load; check Secure Boot and DKMS status.\n' >&2
        fi
    else
        printf 'WARNING: v4l2loopback is not built for the running kernel; reboot into the installed Debian kernel and check dkms status.\n' >&2
    fi
}

install_optional_tools() {
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v copilot >/dev/null 2>&1; then
        if command -v npm >/dev/null 2>&1; then
            if ! npm_config_ignore_scripts=false npm install --global --prefix "$HOME/.local" @github/copilot; then
                setup_failure 'Install GitHub Copilot CLI from the official npm package'
            fi
        else
            setup_failure 'Node/npm is unavailable; GitHub Copilot CLI was not installed'
        fi
    fi
    if command -v pipx >/dev/null 2>&1 && ! command -v protontricks >/dev/null 2>&1; then
        if ! pipx install protontricks; then setup_failure 'Install Protontricks with pipx'; fi
    fi
    if command -v flatpak >/dev/null 2>&1; then
        if ! sudo flatpak remote-add --system --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo; then
            setup_failure 'Add the official Flathub repository for camera controls'
        elif ! sudo flatpak install --system --noninteractive -y flathub hu.irl.cameractrls; then
            setup_failure 'Install the camera control application from Flathub'
        fi
    fi
}

configure_system_profile() {
    local docker_preexisting="${1:-false}"
    RUN_USER="$(id -un)"
    add_user_groups
    if [[ "$(getent passwd "$RUN_USER" | cut -d: -f7)" != /usr/bin/fish ]]; then
        sudo chsh -s /usr/bin/fish "$RUN_USER" || setup_failure "Set Fish as the default shell for $RUN_USER"
    fi

    configure_ssh
    configure_bluetooth_experimental
    configure_firewall
    for unit in wpa_supplicant.service NetworkManager.service bluetooth.service thermald.service tailscaled.service \
        libvirtd.service fwupd-refresh.timer fstrim.timer; do
        enable_system_unit "$unit"
    done
    enable_system_unit ssh.service
    if desktop_installed tlp && ! desktop_installed power-profiles-daemon; then
        enable_system_unit tlp.service
        enable_system_unit tlp-pd.service
    fi
    if user_unit_exists gcr-ssh-agent.socket; then
        systemctl --user enable --now gcr-ssh-agent.socket || setup_failure 'Enable user service gcr-ssh-agent.socket'
    fi
    configure_camera_module
    configure_rootless_docker "$docker_preexisting"
    install_optional_tools
}
