# 软件迁移清单

依据原 `nixos/inventory/thinkbook.json`、软件模块、Home Manager 应用和编辑器扩展整理。
2026-11-21 核验了 Debian Trixie / Backports 的实际包索引与 Homebrew 官方配方。
这里列的是应用及功能对应关系；具体自动安装包名以同目录的软件 `.txt` 清单及 `vscode/extensions/` 分组为准。

| 用途 | 自动安装的软件与命令 | 日常使用 |
| --- | --- | --- |
| 桌面会话 | Hyprland、Hyprpaper、Hypridle、Hyprlock、Hyprland/GTK portals、XWayland、SDDM / Debian Maui | 完整安装先检查新桌面再移除 KDE；登录选择 Hyprland (myconfig)，`bash check-desktop.sh` 检查 |
| 桌面操作 | Waybar、Wofi、wlogout、Dunst、Grim、Slurp、wl-clipboard、brightnessctl、playerctl | 启动器、通知、区域截图、剪贴板、亮度和媒体键 |
| 网络与蓝牙 | NetworkManager、nm-applet、nmtui、BlueZ、Blueman | 顶栏托盘或 `nmtui` 配置网络，Blueman 管理蓝牙 |
| 声音 | PipeWire、WirePlumber、ALSA 工具、pavucontrol | `wpctl status`；面板调整设备、应用音量 |
| 输入法 | Fcitx5、中文附加组件、GTK3/Qt5/Qt6 前端、配置工具、im-config | `Ctrl+Space` 拼音切换；`fcitx5-configtool` 设置 |
| 中文与字体 | Noto CJK/Emoji、JetBrains Mono/Nerd Font、Font Awesome、DejaVu、FreeFont、TeX Gyre、Unifont、Liberation、Carlito、Caladea、URW | 中英文、图标、办公字体替代；`fc-match` 检查实际匹配 |
| 认证与主题基础 | PolicyKit/MATE agent、GNOME Keyring、Papirus、Bibata、Qt5ct/Qt6ct/Kvantum、GTK 平台主题 | 图形授权、密码存储、应用图标与主题配置；不用免密 sudo |
| 终端与 shell | Kitty、Fish、Oh My Posh、tmux、Zoxide、direnv | 原提示符和 tmux 主题；`z` 跳目录，可信项目执行 `direnv allow` |
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
| 容器 | Debian Docker Engine、Compose、Buildx、rootlesskit、slirp4netns、uidmap、fuse-overlayfs | `sudo docker ...`；原 rootless 服务需按 `MANUAL.md` 单独迁移 |
| 虚拟化 | QEMU/KVM、libvirt、virt-manager、OVMF | 使用 virt-manager 创建 UEFI 虚拟机；服务与权限另行检查 |
| 远程与 Agent | Tailscale、OpenSSH、RustDesk、Codex、GitHub Copilot CLI | 完成账户认证；SSH 密钥、防火墙、RustDesk 输入服务见 `MANUAL.md` |
| LaTeX | TeX Live 的 XeTeX、LaTeX Extra、中文、BibTeX Extra、科学排版及推荐字体、latexmk、Biber | 含 `xelatex`、`pdflatex`、BibTeX、Biber；`latexmk -xelatex main.tex` |
| 新式排版 | Typst、Tinymist、Texlab、Pandoc | `typst compile main.typ`，`pandoc input.md -o output.docx` |
| 图形与创作 | draw.io、Inkscape、Krita、Blender、Blockbench | 架构图、SVG、绘画、3D 与低多边形模型；通过应用菜单启动 |
| 图像/影音命令 | FFmpeg/ffprobe、ImageMagick、ffmpegthumbnailer、Poppler、Ghostscript、DjVu、jpegoptim、optipng | 抽帧、转码、缩略图、PDF/图像处理 |
| 会议与文件互传 | Zoom、LocalSend | 应用菜单启动；Zoom 也可用 `zoom`，LocalSend 网络访问取决于本机防火墙 |
| 摄像头与录制 | guvcview、v4l-utils、OBS Studio、v4l2loopback DKMS/工具和 Debian 内核头文件 | `v4l2-ctl --list-devices`；OBS 虚拟摄像头需确认模块加载成功 |
| Steam/Wine | Steam、steam-devices、GameMode、MangoHud、Wine/Winetricks、32 位 Wine/Mesa/Vulkan | Steam 首次下载客户端；Proton-GE、Protontricks、Gamescope 与游戏数据见手动清单 |
| 电源/硬件 | TLP/tlp-pd（Backports）、thermald、powertop、fwupd、Intel Wi-Fi/SOF/显卡固件及微码 | 先解决与已有电源管理器的冲突，再验收充电策略与休眠 |
| 图形/视频诊断 | mesa-utils、vulkan-tools、vainfo、Intel VA-API 驱动 | `glxinfo -B`、`vulkaninfo --summary`、`vainfo` |
| 磁盘与救援 | GParted、GNOME 磁盘、TestDisk、ddrescue、smartmontools、nvme-cli、hdparm、cryptsetup、parted、Timeshift、rsync | 分区/健康/恢复/快照工具已安装，操作对象及任务需用户自行设置 |
| 文件系统 | Btrfs、NTFS-3G、exFAT、FAT/mtools、FUSE2 兼容库 | 外接介质支持；不更改现有文件系统或磁盘布局 |
| SQLite/SQL | sqlite3、DB Browser for SQLite、VisiData、LazySQL、Harlequin | `sqlite3 database.db`、`harlequin database.db`，或使用图形数据库工具 |
| 磁盘占用 | QDirStat、Baobab、ncdu、dust、duf | `ncdu ~` / `dust` 查看目录，`duf` 查看分区 |
| 监控/诊断 | btop、htop、s-tui、nvtop、Fastfetch、pciutils、usbutils、strace、time、DNS/whois 工具 | 排查 CPU/GPU、温度、设备和网络问题 |

未自动安装的原软件完整列在 [MANUAL.md](MANUAL.md)：WPS、微信、QQ、腾讯会议、Zotero 及两个插件、
IDEA、Godot .NET、Aseprite、Conda、Clash Verge Rev、网易云 GTK、HMCL、oh-my-pi、termpdf.py、
cameractrls、Protontricks、Gamescope、Proton-GE、WoeUSB、USBImager、UNetbootin、pwvucontrol，
以及 Mental Omega 3.3.6 游戏和中文补丁。它们不计入“自动安装完成”。

原 NixOS 自动生成的系统包、引导工具、Nix 专用工具、登录器和旧桌面会话的处理方式也见该文件。
不会为了表面上匹配旧清单而覆盖 Debian 的引导/PAM、安装第二套 libc，或同时启动多个桌面与电源策略管理器。
