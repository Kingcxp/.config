# 软件迁移清单

依据原 `nixos/inventory/thinkbook.json`、软件模块、Home Manager 应用和编辑器扩展整理。
Debian Trixie / Backports 包名于 2026-11-22 对照 Debian 官方索引核验；Homebrew 与扩展的显式项目以仓库清单为准。
这里列的是应用及功能对应关系；具体自动安装包名以同目录的软件 `.txt` 清单及 `vscode/extensions/` 分组为准。

| 用途 | 自动安装的软件与命令 | 日常使用 |
| --- | --- | --- |
| 引导与固件 | UEFI GRUB、`efibootmgr`、Catppuccin Macchiato GRUB 主题 | Debian 安装器负责 ESP 和启动项；安装脚本检查 UEFI/ESP、安装校验过的 Catppuccin GRUB 主题并运行 `update-grub`，不分区或格式化磁盘 |
| 桌面会话 | Hyprland、Hyprland GUI utilities、Hyprpaper、Hypridle、Hyprlock、Hyprland/GTK portals、XWayland、SDDM / Catppuccin Macchiato-Lavender | 完整安装先检查新桌面再移除 KDE；登录选择 Hyprland (myconfig)，`bash check-desktop.sh` 检查 |
| 桌面操作 | Waybar、Wofi、wlogout、Dunst、Grim、Slurp、wl-clipboard、brightnessctl、playerctl | 启动器、通知、区域截图、剪贴板、亮度和媒体键 |
| 网络与蓝牙 | NetworkManager、wpa_supplicant、ModemManager、nm-applet、nmtui、BlueZ（Experimental=true）、Blueman | Wi-Fi 与移动宽带服务随 NetworkManager 使用；托盘或 `nmtui` 配置网络，Blueman 管理蓝牙 |
| 声音 | PipeWire、WirePlumber、RTKit、ALSA 工具、freedesktop 音效主题、pavucontrol | `wpctl status`；面板调整设备、应用音量 |
| 输入法 | Fcitx5、中文附加组件、GTK3/GTK4/Qt5/Qt6 前端、Debian `fcitx5-modules` 内置的 Wayland 前端、配置工具、im-config | `Ctrl+Space` 拼音切换；Wayland 原生输入使用文本输入协议，GTK portal 单独启用 Fcitx 前端 |
| 中文与字体 | Noto CJK/Emoji、JetBrains Mono/Nerd Font、Font Awesome、DejaVu、FreeFont、TeX Gyre、Unifont、Liberation、Carlito、Caladea、URW | 中英文、图标、办公字体替代；`fc-match` 检查实际匹配 |
| 认证与主题基础 | PolicyKit/MATE agent、GNOME Keyring、Speech Dispatcher、Catppuccin Macchiato/Lavender GTK/光标/Kvantum/Fcitx5/SDDM/GRUB、Papirus 图标、Qt5ct/Qt6ct | 图形授权、密码存储、屏幕阅读器语音接口、与 NixOS 同名的桌面/输入/引导主题；不用免密 sudo |
| 终端与 shell | Kitty、Fish、Oh My Posh、tmux、Zoxide、direnv | Fish 语法高亮和原布局提示符统一为 Macchiato；tmux 为 Mocha；`z` 跳目录，可信项目执行 `direnv allow` |
| 文件与压缩 | Dolphin、Ark、Yazi、GNOME 归档管理器、GVfs、udisks2/udiskie、7zip、unrar、unar、zip/unzip、zstd | 图形/终端文件管理，外接盘挂载，常用压缩格式 |
| 浏览器 | Firefox ESR、Microsoft Edge | 主浏览器与备用浏览器；文献抓取扩展见手动清单 |
| 编辑器 | VS Code、Zed、Neovim/AstroNvim、Neovide、Micro、Vim、Nano | `code .`、`zed .`、`nvim`；Neovim 插件首次联网获取 |
| VS Code 扩展 | 默认 19 项显式请求：7 通用 + 12 科研；`bash install-vscode.sh --list` 查看其他扩展组 | 保留 Python/Pylance/Jupyter/Ruff、LaTeX/Typst、CSV、SSH；其他语言和工具可按 Profile 安装。依赖或子包可额外安装，旧扩展不自动移除 |
| Git | Git、Git LFS、GitHub CLI (`gh`)、pre-commit | `gh auth login`；`pre-commit install`，个人签名密钥另行恢复 |
| Python | Python 3、pip、venv、virtualenv、pipx、uv、Ruff、Pyright | 优先使用项目环境，不向 Debian 的系统 Python 运行 `sudo pip` |
| C/C++ | GCC/Make、CMake、Ninja、pkg-config、binutils、GDB、ccache、Clang/clangd/clang-tools、LLVM/LLD、Xmake | `cmake -S . -B build -G Ninja`；`cmake --build build` |
| Go | Go、gopls、golang-golang-x-tools | `go test ./...`，编辑器连接 gopls |
| Rust | rustc、Cargo、Clippy、rustfmt、rust-analyzer | `cargo test`、`cargo clippy`；版本随 Debian 稳定仓库 |
| Java | OpenJDK 21、Maven、Homebrew Gradle | 以项目自带 `mvnw` / `gradlew` 优先，避免依赖全局构建工具版本 |
| JS/TS | Node 22/npm、Bun、Deno、pnpm、TypeScript、typescript-language-server | `pnpm install`，按项目锁文件选择包管理器；Node 22 优先进入 PATH |
| .NET | Homebrew .NET SDK | `dotnet --info`；Godot/旧项目的 SDK 和运行时按项目补齐 |
| LSP 与格式化 | Lua/Bash/YAML/JSON 语言服务、Pyright、StyLua、tree-sitter、Alejandra 等 | 提供给 Neovim/编辑器；使用项目需要的版本 |
| 任务与终端助手 | Just、ripgrep、fd-find、fzf、bat、eza、tlrc/tldr、tree、wget | `just` 运行项目任务；Debian 的 `batcat` / `fdfind` 已配置 Fish 别名 |
| 容器 | Debian Docker Engine、Compose、Buildx、rootlesskit、slirp4netns、uidmap、fuse-overlayfs | rootless 用户服务自动配置；重新登录后 `docker run`，无需 `sudo` |
| 虚拟化 | QEMU/KVM、libvirt、virt-manager、OVMF | 自动启用服务并加入 `libvirt`/`kvm` 组；重新登录后创建 UEFI 虚拟机 |
| 远程与 Agent | Tailscale、OpenSSH、RustDesk、Codex CLI、Codex App (Web) 桌面入口、GitHub Copilot CLI | tailscaled 自动启用；`tailscale up --netfilter-mode=nodivert --ssh=false` 登录。Codex CLI 用 `codex` 启动，Web 入口复用 Edge 登录态；UFW 仅允许 Tailnet SSH，RustDesk 输入服务见 `MANUAL.md` |
| LaTeX | TeX Live 的 XeTeX、LaTeX Extra、中文、BibTeX Extra、科学排版及推荐字体、latexmk、Biber | 含 `xelatex`、`pdflatex`、BibTeX、Biber；`latexmk -xelatex main.tex` |
| 新式排版 | Typst、Tinymist、Texlab、Pandoc | `typst compile main.typ`，`pandoc input.md -o output.docx` |
| 图形与创作 | draw.io、Inkscape、Krita、Blender、Blockbench | 架构图、SVG、绘画、3D 与低多边形模型；通过应用菜单启动 |
| 图像/影音命令 | FFmpeg/ffprobe、ImageMagick、ffmpegthumbnailer、Poppler、Ghostscript、DjVu、jpegoptim、optipng | 抽帧、转码、缩略图、PDF/图像处理 |
| 会议与文件互传 | Zoom、LocalSend | 应用菜单启动；Zoom 也可用 `zoom`，LocalSend 网络访问取决于本机防火墙 |
| 摄像头与录制 | guvcview、Flathub cameractrls、v4l-utils、OBS Studio、v4l2loopback DKMS/工具和 Debian 内核头文件 | `v4l2-ctl --list-devices`；虚拟设备自动配置，Secure Boot 可能要求签名模块 |
| Steam/Wine | Steam、steam-devices、GameMode、MangoHud、Wine/Winetricks、32 位 Wine/Mesa/Vulkan、Backports Gamescope、pipx Protontricks | Steam 首次下载客户端；仅 Proton-GE 与游戏数据仍需手动安装 |
| 电源/硬件 | TLP/tlp-pd（Backports）、thermald、powertop、fwupd、Intel Wi-Fi/SOF/显卡固件及微码 | 先解决与已有电源管理器的冲突，再验收充电策略与休眠 |
| 图形/视频诊断 | mesa-utils、vulkan-tools、vainfo、Intel VA-API 驱动 | `glxinfo -B`、`vulkaninfo --summary`、`vainfo` |
| 磁盘与救援 | GParted、GNOME 磁盘、TestDisk、ddrescue、smartmontools、nvme-cli、hdparm、cryptsetup、parted、Timeshift、rsync | 分区/健康/恢复/快照工具已安装，操作对象及任务需用户自行设置 |
| 文件系统 | Btrfs、NTFS-3G、exFAT、FAT/mtools、FUSE2 兼容库 | 外接介质支持；不更改现有文件系统或磁盘布局 |
| SQLite/SQL | sqlite3、DB Browser for SQLite、VisiData、LazySQL、Harlequin | `sqlite3 database.db`、`harlequin database.db`，或使用图形数据库工具 |
| 磁盘占用 | QDirStat、Baobab、ncdu、dust、duf | `ncdu ~` / `dust` 查看目录，`duf` 查看分区 |
| 监控/诊断 | btop、htop、s-tui、nvtop、Fastfetch、pciutils、usbutils、strace、time、DNS/whois 工具 | 排查 CPU/GPU、温度、设备和网络问题 |

## 精确安装清单

以下为安装脚本默认请求的显式包名，不含 APT 自动解析的依赖包、Homebrew 的间接依赖或 VS Code 扩展的依赖扩展。稳定仓库清单 271 项、Backports 9 项、第三方 APT 仓库 3 项，共 283 项；Homebrew 与扩展安装失败会记录在 `~/.local/state/myconfig-debian/failed-packages.txt` 或扩展失败清单中。

| Debian Trixie 分组 | 显式包名 |
| --- | --- |
| UEFI 引导与固件变量（2） | `grub-efi-amd64`, `efibootmgr` |
| 桌面、门户与控制（32） | `sddm`, `sddm-theme-debian-maui`（保留备用）, `qml6-module-qtquick`, `qml6-module-qtquick-controls`, `qml6-module-qtquick-layouts`, `qml6-module-qtquick-window`, `qml6-module-qtquick-templates`, `qml6-module-qtqml-models`, `qml6-module-qtqml-workerscript`, `libqt6svg6`, `qt6-svg-plugins`, `dbus-user-session`, `waybar`, `wofi`, `wlogout`, `dunst`, `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xwayland`, `grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `playerctl`, `libnotify-bin`, `mate-polkit`, `pkexec`, `polkitd`, `rtkit`, `speech-dispatcher`, `sound-theme-freedesktop`, `hicolor-icon-theme` |
| 音频、网络、蓝牙与输入法（28） | `pipewire-audio`, `pipewire-pulse`, `pipewire-alsa`, `alsa-ucm-conf`, `libspa-0.2-bluetooth`, `libpipewire-0.3-0t64:i386`, `libspa-0.2-modules:i386`, `pipewire-alsa:i386`, `wireplumber`, `pavucontrol`, `network-manager`, `network-manager-gnome`, `wpasupplicant`, `modemmanager`, `bluez`, `blueman`, `firmware-iwlwifi`, `firmware-intel-graphics`, `firmware-misc-nonfree`, `firmware-sof-signed`, `intel-microcode`, `intel-media-va-driver`, `fcitx5`, `fcitx5-chinese-addons`, `fcitx5-frontend-gtk3`, `fcitx5-frontend-gtk4`, `fcitx5-frontend-qt5`, `fcitx5-frontend-qt6` |
| 常用应用（9） | `kitty`, `dolphin`, `firefox-esr`, `micro`, `fish`, `tmux`, `btop`, `powertop`, `zenity` |
| LaTeX 与文档转换（6） | `texlive-xetex`, `texlive-lang-chinese`, `texlive-latex-extra`, `latexmk`, `biber`, `pandoc` |
| 字体与图标（7） | `fonts-jetbrains-mono`, `fonts-font-awesome`, `fonts-noto-cjk`, `fonts-noto-color-emoji`, `papirus-icon-theme`, `adwaita-icon-theme`, `bibata-cursor-theme` |
| Shell、构建基础与常用命令（28） | `git`, `curl`, `wget`, `ca-certificates`, `build-essential`, `cmake`, `pkg-config`, `python3`, `python3-venv`, `python3-pip`, `unzip`, `zip`, `xz-utils`, `file`, `ncurses-term`, `acpi`, `bc`, `fontconfig`, `xdg-utils`, `ffmpegthumbnailer`, `poppler-utils`, `imagemagick`, `zoxide`, `eza`, `bat`, `fd-find`, `ripgrep`, `fzf` |
| 会话集成、Qt 与硬件诊断（31） | `gnome-keyring`, `libpam-gnome-keyring`, `gcr`, `dconf-cli`, `gsettings-desktop-schemas`, `xdg-user-dirs`, `shared-mime-info`, `udisks2`, `udiskie`, `gvfs`, `gvfs-backends`, `qtwayland5`, `qt6-wayland`, `qt5ct`, `qt6ct`, `qt5-style-kvantum`, `qt6-style-kvantum`, `qt6-gtk-platformtheme`, `qt5-gtk-platformtheme`, `alsa-utils`, `mesa-utils`, `mesa-vulkan-drivers`, `vulkan-tools`, `vainfo`, `fwupd`, `bolt`, `thermald`, `upower`, `fcitx5-config-qt`, `im-config`, `locales` |
| 文件管理、Shell 与压缩（17） | `ark`, `file-roller`, `vim`, `nano`, `htop`, `fastfetch`, `tree`, `unar`, `unrar`, `7zip`, `zstd`, `flatpak`, `man-db`, `bash-completion`, `direnv`, `gh`, `git-lfs` |
| 学术写作、绘图与影音（11） | `texlive-bibtex-extra`, `texlive-fonts-recommended`, `texlive-science`, `ffmpeg`, `inkscape`, `krita`, `blender`, `jpegoptim`, `optipng`, `ghostscript`, `djvulibre-bin` |
| 补充字体（9） | `fonts-noto-core`, `fonts-dejavu`, `fonts-freefont-ttf`, `fonts-texgyre`, `fonts-unifont`, `fonts-liberation`, `fonts-crosextra-carlito`, `fonts-crosextra-caladea`, `fonts-urw-base35` |
| 开发工具链（24） | `gnupg`, `ninja-build`, `binutils`, `gdb`, `ccache`, `clang`, `clang-tools`, `clangd`, `llvm`, `lld`, `python3-virtualenv`, `pipx`, `pre-commit`, `just`, `golang-go`, `gopls`, `golang-golang-x-tools`, `rustc`, `cargo`, `rust-clippy`, `rustfmt`, `rust-analyzer`, `openjdk-21-jdk`, `maven` |
| 容器、虚拟机、SSH 与防火墙（16） | `docker.io`, `docker-compose`, `docker-buildx`, `rootlesskit`, `slirp4netns`, `uidmap`, `fuse-overlayfs`, `qemu-system-x86`, `qemu-utils`, `libvirt-daemon-system`, `libvirt-clients`, `virt-manager`, `ovmf`, `openssh-client`, `openssh-server`, `ufw` |
| 摄像头与 OBS（6） | `guvcview`, `v4l-utils`, `obs-studio`, `linux-headers-amd64`, `v4l2loopback-dkms`, `v4l2loopback-utils` |
| 存储、救援、SQL 与监控（34） | `gparted`, `gnome-disk-utility`, `testdisk`, `gddrescue`, `smartmontools`, `nvme-cli`, `hdparm`, `cryptsetup`, `timeshift`, `parted`, `wimtools`, `btrfs-progs`, `ntfs-3g`, `exfatprogs`, `dosfstools`, `mtools`, `rsync`, `sqlite3`, `sqlitebrowser`, `visidata`, `qdirstat`, `baobab`, `ncdu`, `du-dust`, `duf`, `s-tui`, `nvtop`, `pciutils`, `usbutils`, `strace`, `time`, `bind9-dnsutils`, `whois`, `libfuse2t64` |
| Steam、32 位图形与 Wine（11） | `steam-installer`, `steam-devices`, `gamemode`, `mangohud`, `mangohud:i386`, `wine`, `wine64`, `wine32:i386`, `winetricks`, `libgl1-mesa-dri:i386`, `mesa-vulkan-drivers:i386` |

| 额外仓库 | 显式安装项 |
| --- | --- |
| Debian Trixie Backports（9） | `hyprland`, `hyprland-guiutils`, `hyprpaper`, `hypridle`, `hyprlock`, `xdg-desktop-portal-hyprland`, `gamescope`, `tlp`, `tlp-pd` |
| 官方厂商 APT 仓库（3） | Tailscale：`tailscale`；Microsoft VS Code：`code`；Microsoft Edge：`microsoft-edge-stable` |

| Homebrew 类型 | 显式安装项 |
| --- | --- |
| Linux formula（29） | `yazi`, `oh-my-posh`, `neovim`, `neovide`, `uv`, `ruff`, `xmake`, `typst`, `tinymist`, `texlab`, `node@22`, `bun`, `deno`, `pnpm`, `typescript`, `typescript-language-server`, `gradle`, `dotnet`, `lazysql`, `harlequin`, `bash-language-server`, `lua-language-server`, `pyright`, `stylua`, `tree-sitter`, `vscode-langservers-extracted`, `yaml-language-server`, `alejandra`, `tlrc` |
| Linux cask（8） | `codex`（Codex CLI）, `drawio`, `rustdesk`, `localsend`, `blockbench`, `zoom`, `zed`, `font-jetbrains-mono-nerd-font` |

| VS Code 扩展组 | 默认显式安装项 |
| --- | --- |
| 通用（7） | `ms-ceintl.vscode-language-pack-zh-hans`, `catppuccin.catppuccin-vsc`, `pkief.material-icon-theme`, `editorconfig.editorconfig`, `tamasfe.even-better-toml`, `redhat.vscode-yaml`, `yzhang.markdown-all-in-one` |
| 科研与 Python（12） | `ms-python.python`, `ms-python.vscode-pylance`, `ms-python.debugpy`, `ms-python.vscode-python-envs`, `charliermarsh.ruff`, `ms-toolsai.jupyter`, `ms-toolsai.jupyter-keymap`, `ms-toolsai.jupyter-renderers`, `james-yu.latex-workshop`, `myriad-dreamin.tinymist`, `mechatroner.rainbow-csv`, `ms-vscode-remote.remote-ssh` |
| Common-only 模式 | `bash install-vscode.sh --bundle core` 只安装上面的 7 个通用扩展 |
| 额外扩展组（默认不安装） | `codex`, `cpp`, `dotnet`, `go`, `java`, `markdown-preview`, `marp`, `mermaid`, `remote`, `rust`, `tools`, `wakatime`, `web`；运行 `bash install-vscode.sh --list` 查看说明，按需运行 `bash install-vscode.sh --bundle <分组>` 安装。`research` 已包含在默认安装中 |

## 安装器额外动作

| 类型 | 自动执行的内容 |
| --- | --- |
| Homebrew | 未安装时运行 Homebrew 官方 Linux 安装器；已有 formula/cask 会跳过，不自动卸载或覆盖 |
| 命令行工具 | 通过官方 npm 包安装 GitHub Copilot CLI（`@github/copilot`）；通过 `pipx` 安装 Protontricks |
| 摄像头控制 | 添加 Flathub 系统 remote，并安装 `hu.irl.cameractrls` |
| 字体缓存 | Homebrew 软件安装后刷新 `fc-cache` |
| 桌面配置 | 备份冲突的用户文件，再链接 `config/` 中的 Hyprland、Waybar、Fcitx5、GTK/Qt、终端、Shell、tmux 和 Codex Web 桌面入口等配置 |

## 自动配置的系统

| 部分 | 配置内容 |
| --- | --- |
| 桌面与显示 | SDDM 使用 Catppuccin Macchiato/Lavender 并关闭虚拟键盘；启用 Hyprland Lua、Hyprpaper/Hypridle/Hyprlock、XWayland 和 portal。内屏 `eDP-1` 首选模式、约 166.7% 缩放；Waybar 15px/28px，显式加载样式并固定 JetBrainsMono Nerd Font 的数字/英文/图标，中文按缺字回退；左标题/硬件、中间桌面编号相隔 6px、右托盘/控制/电池与功耗；保留 dwindle 和原快捷键 |
| 中文与输入 | `zh_CN.UTF-8`、`Asia/Shanghai`；Fcitx5 拼音用 `Ctrl+Space`。Hyprland 清除继承的全局 GTK 模块变量；GTK3/4 Wayland 走 text-input-v3，X11 由配置文件选择 Fcitx；GTK portal 保留独立覆盖。Qt5 使用 Fcitx 模块，Qt6 优先 `wayland;fcitx;ibus` 回退顺序。其他桌面保留 im-config 的 Fcitx5 设置 |
| 字体与主题 | Noto CJK/Emoji、Font Awesome、JetBrains Mono 和 Nerd Font、DejaVu/FreeFont/TeX Gyre 等；Nerd Font 缺失时安装固定版本并校验。GTK/Qt/dconf 同步 JetBrainsMono Nerd Font 12；安装 Catppuccin Macchiato/Lavender GTK、光标、Kvantum、Fcitx5、GRUB，图标为 Papirus。检查生成的 GRUB 配置含主题、图形输出及可见菜单 |
| 音量与亮度 | Waybar 滚轮反向并按 1% 微调，音量上限 100%、亮度下限 5%；Fn 媒体键保留常规方向并使用 5% 步进 |
| 网络与蓝牙 | 启用 `wpa_supplicant`、NetworkManager、BlueZ、Blueman、thermald；BlueZ 设置 `Experimental=true`，通常在下一次蓝牙服务启动时生效。ModemManager、RTKit、UPower 由包提供并按需经 D-Bus 激活 |
| 远程连接 | 启用 Tailscale、OpenSSH、UFW。SSH 禁止密码和 root 登录，只允许当前用户的公钥认证；TCP 22 仅开放于 `tailscale0`。首次仍需运行 `sudo tailscale up --netfilter-mode=nodivert --ssh=false` 并写入个人 `authorized_keys` |
| 防火墙端口 | Tailnet 上 TCP 22；另开放 TCP `27036`、`27037`、`53317`，UDP `27031-27036`、`41641`、`53317`、`10400-10401`，用于配置中的 Tailscale/Steam/LocalSend 网络功能 |
| Docker | 配置 rootless Docker、Compose/Buildx、日志轮转、subuid/subgid、用户 lingering 和用户级 systemd 服务；新安装的 rootful daemon 会停用，既有 rootful 服务、自定义 daemon 配置与容器不会被强制清除 |
| 虚拟化与用户组 | 启用 libvirt；按机器上存在的组将用户加入 NetworkManager/netdev、video/render、libvirt/kvm、gamemode 组，重新登录后生效 |
| 摄像头 | 安装 OBS/v4l2loopback，配置虚拟设备 `/dev/video10`（名称 `OBS Cam`）并尝试 DKMS 编译/加载；guvcview 选择内置或 USB 摄像头，cameractrls 调节硬件支持的参数 |
| 电源与维护 | 安装 TLP/tlp-pd、fwupd、thermald、upower；在没有 `power-profiles-daemon` 时启用 TLP 服务；启用 fwupd 刷新和 fstrim timer。安装器不配置休眠分区或 resume |
| Fish 与开发会话 | 默认 shell 为 Fish；随配置安装并加载 Macchiato 语法/补全主题，oh-my-posh 同步调色板。Neovim 使用系统/Homebrew 的语言服务而禁用 Mason 自动下载；用户和 systemd 会话获得 Node 22/Homebrew PATH |

## 仍需手动完成

这些项目不会被上述包清单算作“已安装”，入口、账号和操作步骤见 [MANUAL.md](MANUAL.md)。

| 类型 | 软件或步骤 |
| --- | --- |
| 官方或专有桌面程序 | WPS、微信、QQ、腾讯会议、Zotero、Zotero Connector、Better BibTeX、IntelliJ IDEA、Godot .NET、Aseprite、Clash Verge Rev、网易云 GTK、HMCL |
| 个人工具 | Conda/Miniforge、termpdf.py、pwvucontrol |
| 游戏与启动器 | Proton-GE；Mental Omega 3.3.6 安装文件、合法 RA2/Yuri 原版数据及中文补丁；原 NixOS 的 `mental-omega` 启动器未移植到 Debian |
| USB 写盘程序 | WoeUSB-ng、USBImager、UNetbootin；这些程序未进入核验的 Debian 13 官方仓库或 Linux Homebrew 清单，所需部分系统依赖已预装 |
| 远程与账户 | Tailscale 设备登录、Codex/Copilot 登录或 API 凭据、SSH 公钥；RustDesk 的 root 输入服务/无人值守功能需按上游说明另行安装并测试 |
| 可选输入法词库 | NixOS 的维基与萌娘词库没有 Debian 仓库包；Fcitx5 中文附加组件已提供基础拼音，不影响常规输入 |
| 真机专属项目 | 摄像头隐私开关、Secure Boot 下的 DKMS 签名、休眠/resume、充电阈值和游戏控制器等需在 ThinkBook 上验证或按硬件设置 |

内核、Mesa、glibc、PAM、systemd、文件系统、引导器和基础命令由 Debian 管理，不复制 NixOS 的系统 derivation；Nix/Home Manager/NixOS 更新工具不迁移，Niri 及其专用组件由 Hyprland 对应项取代。安装器不会替换 Debian 的引导/PAM，也不会安装第二套 libc 或同时启动两个电源策略管理器。
