# Debian 13 / ThinkBook 13x ITG

将原 `myconfig` 迁移为独立的 Debian 配置，并按原 NixOS 软件集合补充 APT / Homebrew 安装清单。
目标是 **Debian 13 Trixie、amd64**，桌面使用 Hyprland 原生 Lua 配置。
完整软件集包含开发、科研、创作、虚拟化与游戏工具，安装量较大；它不是之前的 32GB U 盘最小验证集。

## 一键安装

先从 UEFI 启动 **Debian 13 amd64** 安装介质，安装器中可以选择 KDE Plasma。ThinkBook 原 NixOS 配置使用 UEFI + GRUB；Debian 安装器会在分区并挂载 ESP 后安装 Debian GRUB。若保留其他系统，EFI 分区不要格式化。确保普通账户可以使用 `sudo`，在 KDE 联网并克隆仓库：

```bash
sudo apt update
sudo apt install -y git python3 sudo ca-certificates
git clone https://github.com/Kingcxp/.config.git ~/myconfig
```

保存工作并**退出 KDE 登录**，按 `Ctrl+Alt+F3`，用同一普通账户登录，然后执行：

```bash
bash ~/myconfig/debian/install.sh --mirror official
```

默认完成全部软件安装、确认 UEFI 启动和 EFI 系统分区挂载、安装并校验 Catppuccin Macchiato/Lavender 主题、刷新 GRUB 菜单、备份和部署用户配置、检查 Hyprland 配置、设置 SDDM 登录入口与主题，最后按明确包名移除 KDE 桌面。**不是先卸载 KDE 再尝试安装新桌面**。
软件安装存在失败、Hyprland 检查失败或 APT 计划包含意外移除包时，不会继续移除 KDE。
安装结束后手动 `sudo reboot`，在 SDDM 选择 **Hyprland (myconfig)**；已预选新会话，不自动重启。首次运行会下载固定版本并校验 SHA-256 的主题资源；GTK/光标在 `/usr/local/share`，Kvantum 在 Debian 插件查找的 `/usr/share/Kvantum`，GRUB 在 `/boot/grub/themes`。重复运行检查版本及必要文件，替换前会备份。
脚本不会分区、格式化 ESP 或猜测 GRUB 写入目标；这些由 Debian 安装器按实际磁盘处理。

首次若想先保留 KDE 验收新桌面，使用 `--keep-kde`；确认后退出图形会话，重新运行默认命令完成移除。
已克隆过时先 `git -C ~/myconfig pull --ff-only`。
这些命令也可以逐行粘贴到 Fish。**不要用 `sudo bash install.sh`**；脚本只对系统操作调用 sudo，
Homebrew、编辑器扩展和用户配置都由当前用户安装。克隆目录需要保留，配置会链接到其中。

已安装旧版（例如 `83b49ed`）时，修复登录虚拟键盘、字体/GTK/Qt 主题、面板布局和 GRUB：

```bash
git -C ~/myconfig pull --ff-only
bash ~/myconfig/debian/repair-desktop.sh
```

修复器只补缺少的桌面依赖（包括 Backports 的 `hyprland-guiutils`）、部署配置和主题、检查 Waybar 实际字体的全部图标、备份并同步 dconf、禁用 SDDM 虚拟键盘、重新生成并检查 GRUB；不重跑全部软件安装，不移除桌面，不重启会话。完成后保存工作并注销重登，新终端加载 Fish 主题；重启时检查 GRUB。检查失败会返回非零并写入 `~/.local/state/myconfig-debian/repair-desktop.log`。

仅修复 Waybar 字体时，在当前 Hyprland 终端运行 `bash ~/myconfig/debian/repair-waybar.sh`。它备份并部署 Waybar 配置、核验字体（缺失或不完整时补装经过校验的 Nerd Font），随后只重启当前用户的 Waybar，无需注销，也不会更新 GRUB 或运行 APT/Homebrew。日志在 `~/.local/state/myconfig-debian/repair-waybar.log` 和 `waybar.log`。

```bash
# 只看完整清单、安装步骤和手动项，不修改系统
bash ~/myconfig/debian/install.sh --mirror official --dry-run

# 使用南大镜像安装；若该网络无法访问镜像，会恢复原有源并退出
bash ~/myconfig/debian/install.sh --mirror nju

# 安装并配置新桌面，暂时保留 KDE
bash ~/myconfig/debian/install.sh --mirror official --keep-kde

# 只安装全部软件，不部署个人桌面配置
bash ~/myconfig/debian/install-software.sh

# 已装好依赖，只部署配置与 tmux 插件；仍可能从 GitHub 下载插件
bash ~/myconfig/debian/install.sh --configs-only

# 随时在终端查看自行安装的软件和首次启用步骤
bash ~/myconfig/debian/install-software.sh --manual
```

## 安装了哪些软件

逐项的软件与用途见 [SOFTWARE.md](SOFTWARE.md)，不能自动安装的项目及服务设置见 [MANUAL.md](MANUAL.md)。

| 清单 | 内容 |
| --- | --- |
| [packages.txt](packages.txt) | Debian 官方仓库的软件：UEFI GRUB/efibootmgr、桌面、中文输入/字体、开发工具链、LaTeX、影音绘图、摄像头、Docker/KVM、磁盘工具、Steam/Wine 等 |
| [lib/install-appearance.sh](lib/install-appearance.sh) | 固定版本并校验 SHA-256 的 Catppuccin GTK、光标、Kvantum、Fcitx5 和 GRUB 主题安装器 |
| [packages-backports.txt](packages-backports.txt) | 配套的 Hyprland、Hyprpaper、Hypridle、Hyprlock、portal、Gamescope，以及 TLP/tlp-pd |
| [packages-vendor.txt](packages-vendor.txt) | 官方签名 APT 源中的 Tailscale、VS Code、Microsoft Edge |
| [brew-formulae.txt](brew-formulae.txt) | Debian 中缺少或需要较新版本的 CLI：Yazi、Oh My Posh、Neovim、uv、Ruff、Typst/LSP、Node 22、Bun、Deno、pnpm、Gradle、.NET 等 |
| [brew-casks.txt](brew-casks.txt) | 已核验 Linux 支持的 Codex CLI、draw.io、RustDesk、LocalSend、Blockbench、Zoom、Zed，以及 Nerd Font；另部署 Codex Web 桌面入口 |
| [VS Code 扩展安装](install-vscode.sh) | 默认 7 项通用 + 12 项科研扩展；`--list` 查看其他语言、容器、AI 与写作扩展组，`--help` 查看 Profile 安装用法 |

安装器还会使用官方 npm 包安装 GitHub Copilot CLI、使用 pipx 安装 Protontricks、从 Flathub 安装 cameractrls；
同时设置中文 locale、Fcitx5 的 GTK/Qt/Wayland 前端、Catppuccin GTK/光标/Kvantum/Fcitx5/GRUB 主题、BlueZ 实验选项、Wi-Fi/移动宽带与 RTKit 服务、rootless Docker、Tailscale/OpenSSH、UFW、摄像头虚拟设备及相关服务。
WPS、微信、QQ、腾讯会议、Zotero + Connector + Better BibTeX、IDEA、Godot .NET、Conda、
Proton-GE、WoeUSB、USBImager、UNetbootin 和 Mental Omega 游戏数据等仍会列在手动清单中，不会误报为“已安装”。
已经存在的 Homebrew 包会保留；需要更新时使用 `brew update`、`brew upgrade`。
APT 软件随 Debian 版本，Homebrew 软件随当前上游配方；不保证与原 Nix 锁文件的版本号完全相同。

## 源、失败处理与备份

首次默认官方源，之后默认沿用上次成功选择；安装参数 `--mirror` 可以覆盖。
安装完成后随时切换（不需要重新安装桌面）：

```bash
bash ~/myconfig/debian/switch-mirror.sh nju
bash ~/myconfig/debian/switch-mirror.sh official
```

官方源为 `deb.debian.org/debian` 与 `security.debian.org/debian-security`；
NJU 为 `mirror.nju.edu.cn/debian` 与 `mirror.nju.edu.cn/debian-security`。
两种模式都明确使用 **trixie、trixie-updates、trixie-security、trixie-backports**，
包含 `main contrib non-free non-free-firmware` 及 amd64/i386，不使用会跨大版本滚动的 `stable`。
旧 Debian `.list` / Deb822 `.sources` 条目和 CD-ROM 源先备份再禁用；同文件中的第三方条目保留。
遇到 sid/bookworm 等外版本或难以安全拆分的混合条目会停止，避免混源。
切换后 APT 验证所选源的签名索引；网络或验证失败会恢复此次修改前的源。
备份在 `/var/backups/myconfig-debian/apt/`。

这里只切换 **Debian APT**；Microsoft、Tailscale、Homebrew、GitHub 和扩展下载继续使用各自官方入口。
脚本先装稳定仓库软件，再显式安装配套 Backports 桌面，允许 APT 同步匹配的 32/64 位依赖；
不强制整机升级到 Backports，也不使用 Ubuntu PPA。

Tailscale 和 Microsoft 仓库使用独立 `Signed-By`；不使用 `apt-key`、`trusted=yes` 或关闭签名检查。
Homebrew 缺失时，下载并执行[官方安装器](https://github.com/Homebrew/install)；后续软件包由 Homebrew 校验。
只安装 Linux 可用的 formula/cask，不将 WPS 等 macOS 安装包写入 Linux 清单。

普通软件安装使用 `--no-remove`。桌面迁移单独模拟并允许将 power-profiles-daemon 换成 TLP/tlp-pd，
并在最后移除 [明确列出的 KDE 桌面包](kde-desktop-packages.txt)；不使用包名通配符或 `autoremove`。
保留 SDDM 登录器、Dolphin/Ark 应用及共享的 Qt/KDE 库，一些无关 KDE 应用和未使用库可能仍留在磁盘上。
完整移除计划与移除前包版本列表保存在用户状态目录；登录配置备份在 `/var/backups/myconfig-debian/desktop/`。
整批安装失败会逐项重试，Homebrew/扩展失败也会继续记录；
**存在失败项时最终返回非零**，不会声称全部完成。
日志与失败清单默认保存在：

```text
~/.local/state/myconfig-debian/install.log
~/.local/state/myconfig-debian/failed-packages.txt
```

修复网络、源或冲突后可重复运行。`install-software.sh` 单独运行时只安装软件，不主动替换电源管理器或移除 KDE；
完整桌面迁移才替换电源管理器并移除 KDE。安装器会保留已有 Docker 容器/SSH 密钥与自定义 Docker 配置，
将 SSH 收紧为当前用户的公钥认证，并配置 UFW 只允许从 Tailscale 接口访问 SSH；首次加入 Tailnet 仍需登录。
它还会设置 rootless Docker 和必要服务。RustDesk 的无人值守键鼠、休眠恢复及游戏数据仍需按 [MANUAL.md](MANUAL.md) 验收。

已有配置在冲突时移动到 `~/.local/state/myconfig-debian/backups/日期-进程号/`，再创建链接。
正确指向当前配置的链接不会反复备份。遇到目录符号链接时先备份该链接，避免改到旧 dotfiles 仓库；
原目标中的其他文件仍保留，可通过备份链接访问。tmux 的 `~/.tmux.conf` 和 `~/.config/tmux/tmux.conf`
会统一到同一份配置，防止旧入口遮蔽主题。

## 桌面与日常使用

安装完成后重启，在保留的 **SDDM** 中选择 **Hyprland (myconfig)**；TTY 可运行 `myconfig-hyprland`。
脚本为 SDDM 选择独立的 Debian Maui 主题，避免主题依赖把已移除的 Plasma 拉回来；NixOS 使用 greetd/regreet，登录管理器不同，所以 SDDM 外观保留为明确差异。
已有自动登录若启用则改指向新会话，不会新开启自动登录；默认 shell 设为 Fish，不设置免密码 sudo。

- **桌面：** 内屏 `eDP-1` 使用首选模式和约 166.7% 缩放，不再要求面板的 BOE 描述完全相同。Waybar 恢复原配置的左侧标题/硬件、中间工作区、右侧托盘/音量/亮度/网络/时钟/电池/功耗；字体 12px、高度 24px。CSS 只指定 JetBrainsMono Nerd Font，专用启动器显式加载配置/样式，并用仅对 Waybar 生效的 Fontconfig 规则避免遗留中文字体别名替换数字。校验同时检查所有图标、ASCII 字符和中文语言环境下 Pango 实际选中的数字字体及字宽；字体缺失的中文字符仍正常回退。保留标题/网络长度限制、dwindle 和原快捷键与动画。
- **快捷键：** `Super+Q` 终端、`Super+E` Dolphin、`Super+F` Firefox、`Super+R` 启动器、`Super+G` 编辑器、`Super+P` 区域截图。取消截图不改剪贴板；`Super+M` 退出菜单只退出当前桌面会话。
- **输入与主题：** 生成 `zh_CN.UTF-8` locale 并设置 `Asia/Shanghai`，`Ctrl+Space` 切换拼音。Hyprland 会话清除继承的 `GTK_IM_MODULE`，GTK3/4 原生 Wayland 使用 text-input-v3，GTK 的 X11 模块由各自配置文件启用；GTK portal 保留专用环境。Qt5 使用 `QT_IM_MODULE=fcitx`，Qt6 以 `QT_IM_MODULES=wayland;fcitx;ibus` 优先选择原生协议并保留回退，依据 [Fcitx 官方说明](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland) 与 Qt 的实现。托盘、GTK、光标、Qt/Kvantum、Fcitx5 和 GRUB 使用 Catppuccin Macchiato/Lavender，图标为 Papirus。Waybar 图标已迁移到 Nerd Fonts 3 码点，检查实际字体中的全部图标，缺失时安装经过校验的字体。GTK/Qt 和 dconf 同步为 JetBrainsMono Nerd Font 12，避免旧 KDE 设置覆盖。Qt5ct/Qt6ct 均使用 `qt5ct` 插件入口；SDDM/Maui 关闭屏幕键盘。
- **音量/亮度：** Waybar 滚轮每次 1%，方向反转，音量上限 100%、亮度下限 5%；Fn 键保持常规方向。背光、充电阈值和电源策略以机器实际暴露的 sysfs 能力为准。
- **tmux：** Mocha 状态栏、CPU/电池插件。若已有 tmux 服务，执行 `tmux source-file ~/.tmux.conf`，或新建会话；已有服务不会被安装器杀掉。
- **Fish：** 使用随仓库提供的 [Catppuccin Macchiato 静态主题](https://github.com/catppuccin/fish)，兼容 Debian 13 的 Fish 4.0；每个交互会话应用主题，覆盖旧 universal 颜色但不改写它们。oh-my-posh 保留原 clean-detailed 布局并同步 Macchiato 调色板；重新打开终端生效，不需要联网安装主题。
- **开发：** `uv init` / `uv add` / `uv run`；`direnv allow` 启用可信项目环境。Neovim 使用 Homebrew 版匹配 AstroNvim；首次打开会联网获取插件，LSP 已启用 APT/Homebrew 安装的服务，不再由 Mason 重复下载工具链。Node 22 的 PATH 同时提供给 Fish、桌面会话和用户服务。
- **排版：** `latexmk -xelatex main.tex` 或 `latexmk -pdf main.tex`；`pandoc input.md -o output.docx`。`typst compile main.typ` 编译 Typst。绘图可用 draw.io、Inkscape、Krita、Blender。
- **远程与 Agent：** `sudo tailscale up --netfilter-mode=nodivert --ssh=false` 加入网络；运行 `codex` 登录 Codex CLI，应用菜单的 **Codex App (Web)** 在 Edge app 模式打开 Codex 网页，`copilot` 单独登录。Linux cask 提供 CLI，不是原生桌面 App。SSH 仅允许 Tailnet 公钥访问。RustDesk 画面捕获和远端输入需分别验收，Homebrew 客户端不附带原 root 服务。
- **容器与虚拟机：** 安装器启用 rootless Docker、Compose/Buildx、libvirt/KVM 服务和用户组；重新登录后使用 `docker info`、`docker compose version` 与 virt-manager 验证。
- **摄像头：** `v4l2-ctl --list-devices` 后用 guvcview 选择内置/USB 摄像头，cameractrls 调节设备参数；安装器配置并尝试加载 OBS 的 v4l2loopback 虚拟设备。

## 登录后的检查

```bash
bash ~/myconfig/debian/check-desktop.sh
hyprctl version
hyprctl configerrors
hyprctl monitors
fc-match 'JetBrainsMono Nerd Font'
fc-match 'Noto Sans CJK SC'
fcitx5-diagnose
nvim --version
node --version
xelatex --version
pdflatex --version
docker compose version
docker info
tailscale status
v4l2-ctl --list-devices
sudo efibootmgr -v
```

再实际验证：中文输入、网络/蓝牙托盘、音量/亮度、屏幕共享、锁屏恢复、退出桌面、
摄像头切换、OBS 虚拟摄像头、Steam 和 RustDesk 远程键鼠。硬件显示器描述可能因面板批次不同，需要按 `hyprctl monitors` 调整。

已在隔离 Debian 13 环境中安装 Backports 桌面运行时，使用实际 Hyprland 的 `--verify-config` 解析通过。
也使用签名的官方索引和真实 APT，按 Debian KDE task 的包状态模拟稳定软件→电源切换→Backports→KDE 移除。
这不是整机图形登录测试，也没有把几千个软件包实际装进 ThinkBook；显示、休眠、输入和远程操作仍需上述真机验收。
NJU 在维护机当前网络下超时，切换成功与否以目标机器的实际签名索引检查为准。
本仓库不添加 GitHub 构建 CI。

在本地运行不安装软件的回归检查：

```bash
python3 -B ~/myconfig/debian/tests/test-apt-sources.py
python3 -B ~/myconfig/debian/tests/test-sddm.py
bash ~/myconfig/debian/tests/test-installer.sh
bash ~/myconfig/debian/tests/test-vscode.sh
bash ~/myconfig/debian/tests/test-mirror.sh
bash ~/myconfig/debian/tests/test-desktop-migration.sh
bash ~/myconfig/debian/tests/test-bootloader.sh
bash ~/myconfig/debian/tests/test-appearance.sh
bash ~/myconfig/debian/tests/test-user-appearance.sh
bash ~/myconfig/debian/tests/test-shell-input.sh
bash ~/myconfig/debian/tests/test-waybar.sh
python3 -B ~/myconfig/debian/lib/check-waybar-fonts.py ~/myconfig/debian/config/.config/waybar/config.jsonc
```

这些测试覆盖切源/失败回滚、配置备份、SDDM 会话、KDE 移除保护、重复运行、安装失败记录、取消截图、UEFI/GRUB 前置检查及主题校验/备份；
它们不代替实际 APT 依赖求解或图形会话测试。

Hyprland Lua 接口对照[官方示例](https://github.com/hyprwm/Hyprland/blob/v0.55.2/example/hyprland.lua)，
通过 Debian 的 [Backports](https://backports.debian.org/Instructions/) 更新；
不混入不匹配的 Mesa/portal 私有版本来追新。
