# Personal desktop configuration

The actively maintained Debian profile lives in [`debian/`](debian/). It targets
Debian 13 Trixie on the ThinkBook 13x ITG and installs the user applications and
their configuration with one script:

```bash
git clone https://github.com/Kingcxp/.config.git ~/myconfig
bash ~/myconfig/debian/install.sh
```

Read [`debian/README.md`](debian/README.md) for the complete APT/Homebrew installer,
Hyprland Lua configuration, backup behavior, and post-install checks.
The [software inventory](debian/SOFTWARE.md) explains the migrated NixOS applications;
[manual steps](debian/MANUAL.md) cover vendor downloads and service setup.

The top-level app directories preserve the original Arch Linux configuration
and are not installed by the Debian script. The installer only links the
Debian-specific copies under `debian/config/`.
