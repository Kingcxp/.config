# Debian profile

This directory contains a Debian 13 (Trixie), amd64 profile migrated from the
repository's `myconfig` files. It installs the desktop and user applications,
then links the bundled configuration into `~/.config`.

## Install

Clone the repository and run the installer as your normal user:

```bash
git clone https://github.com/Kingcxp/.config.git ~/myconfig
bash ~/myconfig/debian/install.sh
```

The installer uses Debian's signed `trixie-backports` archive for Hyprland,
Hyprpaper, Hypridle, Hyprlock, and the Hyprland portal. Debian Backports
currently packages Hyprland 0.55.2; its native Lua config API is used here, and
Hyprland automatically prefers `hyprland.lua` over `hyprland.conf`. The config
syntax follows the [official 0.55.2 Lua example](https://github.com/hyprwm/Hyprland/blob/v0.55.2/example/hyprland.lua).
The upstream release page currently identifies [Hyprland 0.57.2](https://github.com/hyprwm/Hyprland/releases/tag/v0.57.2).
If the system does not already enable Debian's `non-free-firmware` component,
the installer adds its signed Trixie source for Intel Wi-Fi, graphics, and SOF
audio firmware.

All Debian packages are listed in `packages.txt`. Yazi, Oh My Posh, and
JetBrainsMono Nerd Font are not available from the selected Debian archive, so
the installer gets pinned upstream releases and verifies their SHA-256
checksums. Tailscale is installed from its official signed Debian repository,
and the Codex CLI is installed from npm. The three tmux plugins are cloned
shallowly from their upstream repositories.

To inspect the installer's actions without making changes:

```bash
bash ~/myconfig/debian/install.sh --dry-run
```

Existing app configuration is moved to
`~/.local/state/myconfig-debian/backups/` before a link is created. The script
does not change the login manager, enable greetd, change the default shell, or
add passwordless sudo rules. After installation, log out and select **Hyprland**
from the display manager's session menu. If no display manager is installed,
start `Hyprland` from a TTY as your normal user.

## Included configuration

| Directory or file | Purpose |
| --- | --- |
| `config/.config/hypr/` | Lua Hyprland session, Hyprpaper, Hypridle, Hyprlock, and wallpaper |
| `config/.config/waybar/` | Status bar, workspaces, tray, audio, brightness, network, and battery controls |
| `config/.config/fcitx5/` | Fcitx5 Pinyin profile and punctuation settings |
| `config/.config/{wofi,wlogout,dunst}/` | Launcher, logout menu, and notifications |
| `config/.config/{kitty,micro,nvim,fish}/` | Terminal, editors, and Fish shell |
| `config/.config/{btop,yazi}/` | System monitor and file manager themes |
| `config/.tmux.conf` | Catppuccin tmux status line with CPU and battery plugins |
| `config/.config/Code/User/settings.json` | VS Code settings; used when Code is installed separately |

## Use

- **Chinese input:** Fcitx5 starts with the session. `Ctrl+Space` toggles Pinyin; use `Super+Space` to switch input methods.
- **Launch apps:** `Super+R` opens Wofi, `Super+Q` opens Kitty, `Super+E` opens Dolphin, and `Super+F` opens Firefox ESR.
- **Screenshots:** `Super+P` selects a region and copies it to the Wayland clipboard.
- **Power and brightness:** media keys change volume and brightness; Waybar's battery menu exposes supported platform profiles and charge protection. Privileged changes use the graphical PolicyKit prompt. No NOPASSWD rule is needed.
- **Remote access and agents:** run `sudo tailscale up` and follow the sign-in link to add the laptop to your tailnet. Then run `codex` in a terminal and sign in. The installer does not authenticate either service.
- **tmux:** the installer places Catppuccin, CPU, and battery plugins under `~/.config/tmux/plugins/`.
- **LaTeX and writing:** the APT profile installs XeLaTeX, PDFLaTeX, BibTeX, Biber, `latexmk`, Chinese TeX packages, and Pandoc. VS Code itself is installed separately.
- **Suspend and hibernate:** wlogout offers both. Hibernate only works when Debian has a working resume configuration and suitable swap.
- **VS Code:** install VS Code separately; Debian's profile only installs its settings file and does not add Microsoft's package repository.

After the first login, check the compositor config and display detection:

```bash
hyprctl configerrors
hyprctl monitors
fc-match 'JetBrainsMono Nerd Font'
fc-match 'Noto Sans CJK SC'
```

The monitor rule targets the ThinkBook 13x ITG's `BOE 0x0981` panel at
2560x1600 and 166.7% scale, followed by a preferred-mode fallback for external
displays. Review `hyprctl monitors` if the panel descriptor differs on a
particular firmware revision.
