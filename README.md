# .config — Hyprland dotfiles

Personal configuration for Arch Linux running Hyprland, themed with Catppuccin Macchiato.

## What's included

| Path | App |
| --- | --- |
| `hypr/` | Hyprland, hypridle (never blank), hyprlock, hyprpaper |
| `waybar/` | Waybar status bar (battery → powertop control, workspace switcher) |
| `wofi/`, `wlogout/` | App launcher and logout screen |
| `dunst/` | Notification daemon |
| `kitty/`, `micro/`, `nvim/`, `fish/` | Terminal, editors, shell |
| `btop/`, `yazi/` | System monitor, file manager |
| `tmux/` + `.tmux.conf` | tmux with catppuccin theme (submodules) |
| `greetd/` | Optional: greetd login screen config (needs root) |
| `scripts/powertop-toggle.sh` | Battery module helper (→ `~/.config/waybar/scripts/`) |

## Prerequisites

On Arch Linux:

```bash
sudo pacman -S hyprland hypridle hyprlock hyprpaper waybar wofi wlogout \
  dunst kitty micro neovim fish tmux btop yazi brightnessctl playerctl \
  wireplumber powertop fcitx5 dolphin firefox
```

tmux plugins are git submodules, so clone with `--recurse-submodules`.

## Installation

```bash
# 1. Clone into a temp dir (keep the repo as source of truth)
git clone --recurse-submodules https://github.com/Kingcxp/.config.git ~/myconfig

# 2. Symlink (recommended — keeps repo in sync for future updates)
mkdir -p ~/.config
ln -sfn ~/myconfig/hypr      ~/.config/hypr
ln -sfn ~/myconfig/waybar    ~/.config/waybar
ln -sfn ~/myconfig/wofi      ~/.config/wofi
ln -sfn ~/myconfig/wlogout   ~/.config/wlogout
ln -sfn ~/myconfig/dunst     ~/.config/dunst
ln -sfn ~/myconfig/kitty     ~/.config/kitty
ln -sfn ~/myconfig/micro     ~/.config/micro
ln -sfn ~/myconfig/nvim      ~/.config/nvim
ln -sfn ~/myconfig/fish      ~/.config/fish
ln -sfn ~/myconfig/btop      ~/.config/btop
ln -sfn ~/myconfig/yazi      ~/.config/yazi
ln -sfn ~/myconfig/tmux      ~/.config/tmux
ln -sf  ~/myconfig/.tmux.conf ~/.tmux.conf

# 3. Battery helper script (waybar config points here)
mkdir -p ~/.config/waybar/scripts
install -m 755 ~/myconfig/scripts/powertop-toggle.sh ~/.config/waybar/scripts/powertop-toggle.sh

# 4. powertop needs passwordless sudo for the battery right-click to work
echo 'kingcq ALL=(root) NOPASSWD: /usr/bin/powertop' | sudo tee /etc/sudoers.d/powertop
```

> Prefer copying over symlinks? Replace the `ln -sfn` lines above with
> `cp -r ~/myconfig/<dir> ~/.config/<dir>` for each entry.

## Optional: greetd login screen (root)

If you use greetd + regreet (dark Catppuccin theme, auto-login into Hyprland):

```bash
sudo pacman -S greetd regreet
sudo cp ~/myconfig/greetd/config.toml  /etc/greetd/config.toml
sudo cp ~/myconfig/greetd/regreet.css  /etc/greetd/regreet.css
sudo cp ~/myconfig/greetd/regreet.toml /etc/greetd/regreet.toml
sudo systemctl enable --now greetd
```

`[initial_session]` in `config.toml` boots straight into Hyprland; the greeter
shows only after logging out. Reboot to take effect.

## Notes

- Waybar workspace buttons switch workspaces natively; battery right-click opens
  a powertop menu (optimize / enable / disable), middle-click runs one-shot
  auto-tune.
- Alt+Tab switches between the two most recently used workspaces.
- Hypridle never blanks the screen (only dims it), even on battery.
