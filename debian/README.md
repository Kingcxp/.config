# Debian 13 / ThinkBook 13x ITG

将原 `myconfig` 迁移为独立的 Debian 配置，并按原 NixOS 软件集合补充 APT / Homebrew 安装清单。
目标是 **Debian 13 Trixie、amd64**，桌面使用 Hyprland 原生 Lua 配置。
完整软件集包含开发、科研、创作、虚拟化与游戏工具，安装量较大；它不是之前的 32GB U 盘最小验证集。

## 一键安装

先安装 **Debian 13 amd64**，安装器中可以选择 KDE Plasma。确保普通账户可以使用 `sudo`，
在 KDE 联网并克隆仓库：

```bash
sudo apt update
sudo apt install -y git python3 sudo ca-certificates
git clone https://github.com/Kingcxp/.config.git ~/myconfig
```

保存工作并**退出 KDE 登录**，按 `Ctrl+Alt+F3`，用同一普通账户登录，然后执行：

```bash
bash ~/myconfig/debian/install.sh --mirror official
```

默认完成全部软件安装、用户配置备份/部署、Hyprland 配置解析检查、SDDM 登录入口与主题，
最后按明确包名移除 KDE 桌面。**不是先卸载 KDE 再尝试安装新桌面**。
软件安装存在失败、Hyprland 检查失败或 APT 计划包含意外移除包时，不会继续移除 KDE。
安装结束后手动 `sudo reboot`，在 SDDM 选择 **Hyprland (myconfig)**；已预选新会话，不自动重启。

首次若想先保留 KDE 验收新桌面，使用 `--keep-kde`；确认后退出图形会话，重新运行默认命令完成移除。
已克隆过时先 `git -C ~/myconfig pull --ff-only`。
这些命令也可以逐行粘贴到 Fish。**不要用 `sudo bash install.sh`**；脚本只对系统操作调用 sudo，
Homebrew、编辑器扩展和用户配置都由当前用户安装。克隆目录需要保留，配置会链接到其中。

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
| [packages.txt](packages.txt) | Debian 官方仓库的软件：桌面、中文输入/字体、开发工具链、LaTeX、影音绘图、摄像头、Docker/KVM、磁盘工具、Steam/Wine 等 |
| [packages-backports.txt](packages-backports.txt) | 配套的 Hyprland、Hyprpaper、Hypridle、Hyprlock、portal，以及 TLP/tlp-pd |
| [packages-vendor.txt](packages-vendor.txt) | 官方签名 APT 源中的 Tailscale、VS Code、Microsoft Edge |
| [brew-formulae.txt](brew-formulae.txt) | Debian 中缺少或需要较新版本的 CLI：Yazi、Oh My Posh、Neovim、uv、Ruff、Typst/LSP、Node 22、Bun、Deno、pnpm、Gradle、.NET 等 |
| [brew-casks.txt](brew-casks.txt) | 已核验 Linux 支持的 Codex、Copilot、draw.io、RustDesk、LocalSend、Blockbench、Zoom、Zed，以及 Nerd Font |
| [VS Code 扩展安装](install-vscode.sh) | 默认 7 项通用 + 12 项科研扩展；`--list` 查看其他语言、容器、AI 与写作扩展组，`--help` 查看 Profile 安装用法 |

WPS、微信、QQ、腾讯会议、Zotero + Connector + Better BibTeX、IDEA、Godot .NET、Conda、
oh-my-pi、Mental Omega 等不会被误报为“已安装”。脚本在终端输出它们的官方入口及安装步骤。
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
完整桌面迁移才执行这些操作。已有 Docker/SSH 设置会保留；新装 OpenSSH 会预置公钥认证及禁止 root 登录。
软件包自身可能启用服务，软件安装不等于原 NixOS 防火墙、rootless Docker、远程键鼠或休眠策略已经迁移。
这些差异在 [MANUAL.md](MANUAL.md) 中逐项说明。

已有配置在冲突时移动到 `~/.local/state/myconfig-debian/backups/日期-进程号/`，再创建链接。
正确指向当前配置的链接不会反复备份。遇到目录符号链接时先备份该链接，避免改到旧 dotfiles 仓库；
原目标中的其他文件仍保留，可通过备份链接访问。tmux 的 `~/.tmux.conf` 和 `~/.config/tmux/tmux.conf`
会统一到同一份配置，防止旧入口遮蔽主题。

## 桌面与日常使用

安装完成后重启，在保留的 **SDDM** 中选择 **Hyprland (myconfig)**；TTY 可运行 `myconfig-hyprland`。
脚本为 SDDM 选择独立的 Debian Maui 主题，避免主题依赖把已移除的 Plasma 拉回来。
已有自动登录若启用则改指向新会话，不会新开启自动登录；不改变默认 shell、不设置免密码 sudo。

- **桌面：** ThinkBook 内屏规则为 2560×1600、约 166.7% 缩放；Waybar 12px/24px、托盘在左侧，限制长标题与网络内容。窗口采用 dwindle，保留原快捷键与动画。
- **快捷键：** `Super+Q` 终端、`Super+E` Dolphin、`Super+F` Firefox、`Super+R` 启动器、`Super+G` 编辑器、`Super+P` 区域截图。取消截图不改剪贴板；`Super+M` 退出菜单只退出当前桌面会话。
- **输入与主题：** 生成 `zh_CN.UTF-8` locale，用户会话/Fish 使用中文。Fcitx5 拼音使用 `Ctrl+Space`，候选框与菜单采用 Macchiato。Waybar/通知/终端保留原主题，GTK 使用 Debian Adwaita-dark 配合 Macchiato 色表、中文字体和 Papirus 图标，Qt 使用 GTK 平台主题。应用自带 UI 和 libadwaita 的部分控件仍由应用自身控制，不能保证所有专有程序完全同色。
- **音量/亮度：** Waybar 滚轮每次 1%，方向反转，音量上限 100%、亮度下限 5%；Fn 键保持常规方向。背光、充电阈值和电源策略以机器实际暴露的 sysfs 能力为准。
- **tmux：** Mocha 状态栏、CPU/电池插件。若已有 tmux 服务，执行 `tmux source-file ~/.tmux.conf`，或新建会话；已有服务不会被安装器杀掉。
- **开发：** `uv init` / `uv add` / `uv run`；`direnv allow` 启用可信项目环境。Neovim 使用 Homebrew 版匹配 AstroNvim；首次打开会联网获取插件，LSP 已启用 APT/Homebrew 安装的服务，不再由 Mason 重复下载工具链。Node 22 的 PATH 同时提供给 Fish、桌面会话和用户服务。
- **排版：** `latexmk -xelatex main.tex` 或 `latexmk -pdf main.tex`；`pandoc input.md -o output.docx`。`typst compile main.typ` 编译 Typst。绘图可用 draw.io、Inkscape、Krita、Blender。
- **远程：** `sudo tailscale up` 加入网络，`codex` / `copilot` 登录后在项目内工作；RustDesk 画面捕获和远端输入需分别验收，AppImage 不附带原 root 服务。
- **摄像头：** `v4l2-ctl --list-devices` 后用 guvcview 选择内置/USB 摄像头；OBS 录制与虚拟摄像头按手动说明检查驱动。

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
v4l2-ctl --list-devices
```

再实际验证：中文输入、网络/蓝牙托盘、音量/亮度、屏幕共享、锁屏恢复、退出桌面、
摄像头切换、Steam 和 RustDesk 远程键鼠。硬件显示器描述可能因面板批次不同，需要按 `hyprctl monitors` 调整。

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
```

这些测试覆盖切源/失败回滚、配置备份、SDDM 会话、KDE 移除保护、重复运行、安装失败记录及取消截图；
它们不代替实际 APT 依赖求解或图形会话测试。

Hyprland Lua 接口对照[官方示例](https://github.com/hyprwm/Hyprland/blob/v0.55.2/example/hyprland.lua)，
通过 Debian 的 [Backports](https://backports.debian.org/Instructions/) 更新；
不混入不匹配的 Mesa/portal 私有版本来追新。
