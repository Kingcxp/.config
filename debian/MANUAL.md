# 需要手动完成的软件与服务

安装器每次完成后都会在终端输出本文件。下面这些项目尚未自动装好；
APT/Homebrew 的失败项另见 `~/.local/state/myconfig-debian/failed-packages.txt`。

## 官方下载项

这些程序在本次核验的 Debian 仓库及 Linux Homebrew 包中没有合适的发行包。
不要使用同名的 macOS cask，也不要把第三方 Ubuntu PPA 加进 Debian。

| 软件 | 官方入口与安装办法 |
| --- | --- |
| WPS 中文版 | https://linux.wps.cn/ ，选择 Linux x86_64 的 `.deb`，在下载目录运行 `sudo apt install ./实际文件名.deb`。已经自动安装中文字体、办公字体替代和 Qt/Fcitx5 支持。WPS 自带专用字体以官方安装包为准。 |
| 微信 | https://linux.weixin.qq.com/ ，下载 amd64 Debian 包，`sudo apt install ./实际文件名.deb`。 |
| QQ | https://im.qq.com/linuxqq/ ，选择 x86_64 `.deb`，`sudo apt install ./实际文件名.deb`。 |
| 腾讯会议 | https://meeting.tencent.com/download/ ，选择 Debian/Ubuntu x86_64 `.deb`，`sudo apt install ./实际文件名.deb`。Zoom 已由 Homebrew 安装，它们是两个不同的程序。 |
| Zotero | https://www.zotero.org/download/ ，选择 Linux x86_64。解压到 `~/.local/opt/zotero`，在该目录运行 `./set_launcher_icon`，再将其中的 `zotero.desktop` 链接到 `~/.local/share/applications/`。已有文献库先备份后再升级。 |
| Zotero Connector | https://www.zotero.org/download/connectors ，在 Firefox 中安装官方扩展；浏览器扩展不能由 `apt install zotero` 代替。 |
| Better BibTeX | https://retorque.re/zotero-better-bibtex/installation/ ，下载与 Zotero 版本匹配的 `.xpi`；在 Zotero → 工具 → 插件 → 从文件安装。保存 `.bib` 时可使用“保持更新”的自动导出。 |
| IntelliJ IDEA | https://www.jetbrains.com/idea/download/?section=linux ，选择 Linux 版。使用项目的 Maven/Gradle Wrapper；自动安装的 JDK 为 OpenJDK 21。 |
| Godot .NET 版 | https://godotengine.org/download/linux/ ，下载 **.NET** 版本而非标准版；解压后运行。`dotnet --list-sdks` 检查当前 Homebrew SDK，按项目要求补装对应运行时/SDK。 |
| Aseprite | https://www.aseprite.org/download/ ，使用已购买的 Linux/Steam 版本，或依照官方许可和编译文档自行构建。 |
| Clash Verge Rev | https://github.com/clash-verge-rev/clash-verge-rev/releases ，下载 Linux amd64 `.deb` 后 `sudo apt install ./实际文件名.deb`；代理订阅需自己导入。 |
| 网易云 GTK 客户端 | https://github.com/gmg137/netease-cloud-music-gtk ，按上游 Linux 安装说明安装。此处保留的是 NixOS 中的 GTK 复刻版，而非 macOS 网易云 cask。 |
| HMCL | https://hmcl.huangyuhui.net/ ，下载官方启动器，若使用 `.jar` 则运行 `java -jar 实际文件名.jar`。游戏、账户和 Java 版本按实例分别设置。 |
| Conda | https://github.com/conda-forge/miniforge ，使用官方 Linux x86_64 安装器安装 Miniforge；按需运行 `~/miniforge3/bin/conda init fish`，重新打开终端。Python 项目也可直接使用已安装的 `uv`。 |
| termpdf.py | https://github.com/dsanson/termpdf.py ，按上游 README 安装；PDF 日常也可用 Firefox 打开。 |
| Proton-GE | https://github.com/GloriousEggroll/proton-ge-custom/releases ，按官方 README 解压到 `~/.steam/root/compatibilitytools.d/`，重新启动 Steam，在兼容性菜单选择它。 |
| pwvucontrol | https://github.com/saivert/pwvucontrol ，按上游 Linux 安装说明安装；音量面板已自动提供 `pavucontrol`。 |
| WoeUSB | Debian 13 主仓没有此包。Windows ISO 写盘可用上游 WoeUSB-ng：https://github.com/WoeUSB/WoeUSB-ng ，按 README 安装；已自动准备 `wimtools`、`parted`、`ntfs-3g` 等系统依赖。 |
| USBImager | Debian 13 主仓没有此包。Linux amd64 版本从上游下载：https://gitlab.com/bztsrc/usbimager ，按上游说明运行。 |
| UNetbootin | Debian 13 主仓没有此包。需要此工具时从上游 Linux 下载页获取：https://unetbootin.github.io/ ，再按上游说明安装。 |

安装下载的 `.deb` 时，请将命令中的“实际文件名”替换成下载的文件名。
APT 会解析该包的依赖；这与软件已经进入 Debian 官方仓库不是一回事。

## 首次启用与验证

- **Tailscale / Codex / Copilot：** 安装器启用 `tailscaled` 并配置 UFW；运行 `sudo tailscale up --netfilter-mode=nodivert --ssh=false` 登录。Homebrew 的 Linux `codex` cask 安装 Codex CLI，首次运行 `codex` 后选择 ChatGPT 登录；`copilot` 也需单独登录。应用菜单中的 **Codex App (Web)** 在 Edge app 模式打开 `https://chatgpt.com/codex`，复用 Edge 的登录态。它是网页版入口；Codex 原生桌面 App 没有 Linux 发行包。可选 VS Code 扩展用 `bash ~/myconfig/debian/install-vscode.sh --bundle codex` 安装。账户、API Key 和付费订阅不会复制进配置仓库。
- **SSH：** 安装器配置仅公钥登录、禁止 root 登录，并只允许当前 Debian 用户；防火墙只在 `tailscale0` 上开放 TCP 22。把你的公钥放入 `~/.ssh/authorized_keys`，设置 `chmod 700 ~/.ssh`、`chmod 600 ~/.ssh/authorized_keys`，然后用 `tailscale ip -4` 的地址连接。没有公钥时先在本机添加，再从其他设备连接。
- **RustDesk：** Homebrew 安装的是 Linux AppImage 客户端，应用菜单可打开。它不等于 NixOS 中的 root 输入服务；需要无人值守或 Wayland 远端键鼠输入时，使用 https://rustdesk.com/docs/en/client/linux/ 的官方 `.deb` 和服务说明，并分别测试画面捕获与键鼠输入。更换 `.deb` 前运行 `brew uninstall --cask rustdesk`，避免保留两套入口。不要用 `--no-sandbox` 解决启动问题。
- **Docker：** 安装器配置 Debian 的 rootless Docker 用户服务、Compose/Buildx、用户 lingering 与日志轮转；新装的系统级 rootful daemon 会停用，已有 Docker 服务和配置保留。重新登录后运行 `docker info`；可用 `docker run --rm hello-world` 验证，无需 `sudo`。既有自定义 `daemon.json` 会保留。
- **虚拟机：** 安装器启用 libvirt 服务并将当前用户加入可用的 `libvirt` / `kvm` 组；重新登录后在 `virt-manager` 中连接系统 QEMU/KVM。不会重启或替换已有虚拟机。
- **Steam：** 32 位架构、Mesa/Wine 与 Steam 已自动安装。首次启动 Steam 会下载客户端更新；在 Steam → 设置 → 兼容性中启用其他游戏的 Steam Play，Proton 的具体版本由 Steam 下载。
- **Mental Omega 3.3.6：** 游戏本体与合法 RA2/Yuri 数据仍需自己准备；https://mentalomega.com/ 获取官方安装说明和 **3.3.6** 对应语言包。简体中文包：https://mentalomega.com/game/lang/MentalOmega336ChineseSimplified.rar 。单独使用 `WINEPREFIX="$HOME/.local/share/mental-omega/wineprefix" WINEARCH=win32 wineboot` 初始化，不要污染默认 Wine 前缀。后续 .NET/渲染器按游戏官方要求设置，cnc-ddraw：https://github.com/FunkyFr3sh/cnc-ddraw 。原 NixOS 的 `mental-omega` 定制启动器没有直接安装到 Debian；仅安装 Wine 不能视为游戏和中文补丁已经验证可用。
- **摄像头：** `v4l2-ctl --list-devices` 列出内置及 USB 设备；guvcview 负责预览/录像，cameractrls（Flathub）负责参数控制。安装器配置 `v4l2loopback` 的 OBS 虚拟设备并尝试为当前内核编译/加载；如无法启动，检查 `dkms status`、内核头文件及 Secure Boot 模块签名。
- **电源：** 完整桌面迁移会先模拟将 power-profiles-daemon 换成 Backports 的 TLP / tlp-pd，只允许移除这一个冲突服务；异常计划会停止。仅运行软件安装或 `--keep-kde` 时不强制替换，冲突会记录为失败。不应同时运行两个策略管理器。
- **中文和字体：** 安装器生成 `zh_CN.UTF-8`、设置系统时区为 `Asia/Shanghai`，并为 Fcitx5 配置 GTK3/GTK4/Qt5/Qt6；Wayland 前端由 Debian 的 `fcitx5-modules` 提供。重新登录后按 `Ctrl+Space` 切换拼音；`fcitx5-configtool` 调整候选框。常用拼音由 Fcitx5 中文附加组件提供；NixOS 额外的维基/萌娘词库没有 Debian 仓库包，未影响基础拼音输入。`fc-match 'Noto Sans CJK SC'`、`fc-match 'JetBrainsMono Nerd Font'` 核验字体。WPS 若缺少授权专有字体，应使用官方包自带字体或自行提供合法字体。
- **蓝牙：** 安装器启用 BlueZ 的 `Experimental=true` 以匹配 NixOS 配置；该选项在下一次 `bluetooth.service` 启动后生效。
- **LaTeX：** `latexmk -xelatex main.tex` 适用于中文 XeLaTeX 文档；`latexmk -pdf main.tex` 使用 PDFLaTeX；BibLaTeX 项目通常使用 Biber。`pandoc input.md -o output.docx` 转换文稿。
- **Python/AI：** 使用 `uv init`、`uv add`、`uv run` 管理项目。CUDA/PyTorch 等按项目与 GPU 选择安装；这台 ThinkBook 的 Iris Xe 不提供 NVIDIA CUDA。
- **密钥与账号：** 安装器将 Fish 设为默认 shell 并配置系统 locale；仓库不携带你的 SSH 私钥、Git 签名身份、浏览器登录态或任何服务账号，需分别恢复/登录。
- **休眠/分区/快照：** 不会修改磁盘、引导器、swap/resume 或 Timeshift 快照任务；这些取决于实际 Debian 安装方式，软件安装成功不代表休眠或恢复已经通过真机测试。

## Debian 中由系统替代的原 NixOS 项目

Nix、Home Manager、nixos-rebuild、nixd、nix-alien、Nix 缓存/更新脚本及 store 包装不迁移；
Niri/swaybg/swayidle/swaylock/xwayland-satellite 改由 Hyprland/Hyprpaper/Hypridle/Hyprlock/XWayland 提供；
登录保留 Debian 的 SDDM，完整迁移切换到独立的 Debian Maui 主题，并预选 Hyprland (myconfig)。
TTY 可运行 `myconfig-hyprland`；不另外安装 greetd/tuigreet。
内核、Mesa、glibc、PAM、systemd、文件系统和启动工具由 Debian 安装器及 APT 管理，
不照搬 NixOS 的系统 derivation。原定制诊断/面板脚本由 Debian 配置中的对应助手或系统命令替代。
