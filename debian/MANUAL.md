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
| oh-my-pi (`omp`) | https://github.com/can1357/oh-my-pi ，按上游 Linux 安装文档安装；它与 Oh My Posh (`oh-my-posh`) 是不同的软件。 |
| termpdf.py | https://github.com/dsanson/termpdf.py ，按上游 README 安装；PDF 日常也可用 Firefox 打开。 |
| cameractrls | https://github.com/soyersoyer/cameractrls ，按上游 Linux 安装说明安装。多摄像头预览已可使用自动安装的 `guvcview`，参数调节可用 `v4l2-ctl`。 |
| Protontricks | https://github.com/Matoking/protontricks ，按其 pipx 安装说明运行 `pipx install protontricks`；重新登录后可用 `protontricks --gui`。 |
| Gamescope | https://github.com/ValveSoftware/gamescope ，按上游 Linux 构建说明安装；Debian Trixie 当前没有对应官方包。Steam 本身不依赖它才能启动。 |
| Proton-GE | https://github.com/GloriousEggroll/proton-ge-custom/releases ，按官方 README 解压到 `~/.steam/root/compatibilitytools.d/`，重新启动 Steam，在兼容性菜单选择它。 |
| WoeUSB | https://github.com/WoeUSB/WoeUSB ，按官方 Linux 安装说明安装，用于制作 Windows 启动盘。 |
| USBImager | https://bztsrc.gitlab.io/usbimager/ ，选择 Linux 版并按官方说明安装；日常写入 Linux ISO 也可用已装的 GNOME 磁盘。 |
| UNetbootin | https://unetbootin.github.io/ ，仅按官方 Linux 文档按需安装，避免使用 Ubuntu 专用 PPA。 |
| pwvucontrol | https://github.com/saivert/pwvucontrol ，按上游 Linux 安装说明安装；音量面板已自动提供 `pavucontrol`。 |

安装下载的 `.deb` 时，请将命令中的“实际文件名”替换成下载的文件名。
APT 会解析该包的依赖；这与软件已经进入 Debian 官方仓库不是一回事。

## 首次启用与验证

- **Tailscale / Codex / Copilot：** `sudo systemctl enable --now tailscaled`，然后 `sudo tailscale up` 登录；在项目目录运行 `codex` 或 `copilot` 并完成认证。账户、API Key 和付费订阅不会复制进配置仓库。
- **SSH：** 新装 OpenSSH 时，安装器预置仅公钥登录、禁止 root 登录。把你自己的公钥放入 `~/.ssh/authorized_keys`，设置 `chmod 700 ~/.ssh`、`chmod 600 ~/.ssh/authorized_keys`。使用 `tailscale ip -4` 的地址连接；Debian 的防火墙需自己限制来源。本安装器不会自动复刻 NixOS 的“只允许 tailscale0 入站 22”规则。已有 OpenSSH 配置会保留。
- **RustDesk：** Homebrew 安装的是 Linux AppImage 客户端，应用菜单可打开。它不等于 NixOS 中的 root 输入服务；需要无人值守或 Wayland 远端键鼠输入时，使用 https://rustdesk.com/docs/en/client/linux/ 的官方 `.deb` 和服务说明，并分别测试画面捕获与键鼠输入。更换 `.deb` 前运行 `brew uninstall --cask rustdesk`，避免保留两套入口。不要用 `--no-sandbox` 解决启动问题。
- **Docker：** 本安装器采用 Debian 的 Docker/Compose/Buildx；可先用 `sudo docker run --rm hello-world` 验证。它没有自动复刻原 NixOS 的 rootless 服务，不自动把用户加入等同 root 权限的 docker 组。需要 rootless 时按 https://docs.docker.com/engine/security/rootless/ 安装官方 rootless 组件，并使用用户服务。已有 Docker 配置与容器不会主动清理。
- **虚拟机：** 用 `virt-manager` 连接系统 QEMU/KVM。若提示权限，确认 libvirt 服务正常，按需将自己加入 `libvirt` 组并重新登录；不自动重启或替换正在运行的虚拟机。
- **Steam：** 32 位架构、Mesa/Wine 与 Steam 已自动安装。首次启动 Steam 会下载客户端更新；在 Steam → 设置 → 兼容性中启用其他游戏的 Steam Play，Proton 的具体版本由 Steam 下载。
- **Mental Omega 3.3.6：** 游戏本体与合法 RA2/Yuri 数据仍需自己准备；https://mentalomega.com/ 获取官方安装说明和 **3.3.6** 对应语言包。简体中文包：https://mentalomega.com/game/lang/MentalOmega336ChineseSimplified.rar 。单独使用 `WINEPREFIX="$HOME/.local/share/mental-omega/wineprefix" WINEARCH=win32 wineboot` 初始化，不要污染默认 Wine 前缀。后续 .NET/渲染器按游戏官方要求设置，cnc-ddraw：https://github.com/FunkyFr3sh/cnc-ddraw 。原 NixOS 的 `mental-omega` 定制启动器没有直接安装到 Debian；仅安装 Wine 不能视为游戏和中文补丁已经验证可用。
- **摄像头：** `v4l2-ctl --list-devices` 列出内置及 USB 设备；在 guvcview 中选择相应 `/dev/video*`。OBS 虚拟摄像头使用已安装的 v4l2loopback；如无法启动，检查 `dkms status`、当前内核头文件及 Secure Boot 模块签名，按需执行 `sudo modprobe v4l2loopback exclusive_caps=1`。
- **电源：** Backports 的 TLP / tlp-pd 会尝试安装；若它们与已装的 power-profiles-daemon 冲突，脚本会保留原包并报告失败。先决定使用哪套电源管理，再处理失败项，不应同时运行两个策略管理器。
- **中文和字体：** 完整安装后重新登录，使用 Fcitx5 拼音；`fcitx5-configtool` 调整候选框。`fc-match 'Noto Sans CJK SC'`、`fc-match 'JetBrainsMono Nerd Font'` 核验字体。WPS 若缺少授权专有字体，应使用官方包自带字体或自行提供合法字体。
- **LaTeX：** `latexmk -xelatex main.tex` 适用于中文 XeLaTeX 文档；`latexmk -pdf main.tex` 使用 PDFLaTeX；BibLaTeX 项目通常使用 Biber。`pandoc input.md -o output.docx` 转换文稿。
- **Python/AI：** 使用 `uv init`、`uv add`、`uv run` 管理项目。CUDA/PyTorch 等按项目与 GPU 选择安装；这台 ThinkBook 的 Iris Xe 不提供 NVIDIA CUDA。
- **SSH 签名与默认 shell：** 仓库不携带你的私钥、Git 签名身份、浏览器登录态或用户密码；它们需在新机配置。需要将 Fish 设为默认 shell 时自行运行 `chsh -s /usr/bin/fish` 并重新登录。
- **休眠/分区/快照：** 不会修改磁盘、引导器、swap/resume 或 Timeshift 快照任务；这些取决于实际 Debian 安装方式，软件安装成功不代表休眠或恢复已经通过真机测试。

## Debian 中由系统替代的原 NixOS 项目

Nix、Home Manager、nixos-rebuild、nixd、nix-alien、Nix 缓存/更新脚本及 store 包装不迁移；
Niri/swaybg/swayidle/swaylock/xwayland-satellite 改由 Hyprland/Hyprpaper/Hypridle/Hyprlock/XWayland 提供；
greetd/tuigreet 不会取代现有 Debian 登录管理器。若没有登录管理器，在 TTY 登录后运行 `Hyprland`。
内核、Mesa、glibc、PAM、systemd、文件系统和启动工具由 Debian 安装器及 APT 管理，
不照搬 NixOS 的系统 derivation。原定制诊断/面板脚本由 Debian 配置中的对应助手或系统命令替代。
