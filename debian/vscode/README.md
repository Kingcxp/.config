# VS Code 扩展整理与性能排查

2026-11-21 对照当前 Windows 维护机的 Scoop 便携版 VS Code 1.146.0，
读取了扩展清单、扩展声明、用户设置和历史日志。没有更改本机设置、卸载扩展或启动编辑器。
这里的结果属于这台 Windows 维护机，不能直接当作 ThinkBook / Debian 的实测结果。

## 已确认的情况

- 共 **101 个不同扩展 ID**；最近一次会话的日志记录其中 38 个被激活。注册表有 102 条记录，其中 Remote SSH 有平台/版本重复记录，
  不能据此认为运行时启动了两份 Remote SSH。完整逐项建议见 [LOCAL-EXTENSIONS.md](LOCAL-EXTENSIONS.md)。
- 23 个扩展声明了 `*` 或 `onStartupFinished` 激活事件；此外，语言、打开的文件与
  `workspaceContains` 也会激活扩展。插件数量、安装体积、声明的事件都不等于 CPU 耗时排名。
- 以下三次启动都出现了扩展宿主无响应。时间取自同一次会话的 `exthost.log`：

| 会话 | 扩展宿主启动 | Eager extensions activated | 两标记间耗时 |
| --- | --- | --- | --- |
| 2026-11-18 16:07:58 | 16:08:00.386 | 16:09:10.023 | 69.637 秒 |
| 2026-11-18 22:13:03 | 22:13:07.214 | 22:13:56.737 | 49.523 秒 |
| 2026-11-21 15:00:09 | 15:00:11.665 | 15:01:06.205 | 54.540 秒 |

这表示启动阶段的扩展初始化存在明显延迟，**不是整个应用的启动时间，也不是某个插件的独立耗时**。
最近一次 `renderer.log` 多次记录 `Extension host … is unresponsive` 和自动启动性能采样，
但日志目录中没有找到可用的 CPU profile；因此尚不能证明哪个扩展占用了最多 CPU。
检查时 VS Code 没有运行，无法读取当前进程负载或进行真实的禁用前后测速。

## 优先处理的扩展

| 优先级 | 扩展 / 组合 | 实际依据与建议 |
| --- | --- | --- |
| 1 | `vscjava.migrate-java-to-azure` | Python 项目启动日志中也被激活；声明递归匹配 `**/*.py` 等，且同一会话出现 `appmod-*` 工具未注册错误。不做 Azure 迁移时先禁用；错误与卡顿同时出现不能证明因果。 |
| 1 | `ms-dotnettools.upgrade-agent` | 声明 `onStartupFinished`，还依赖 Copilot Chat / .NET runtime。仅在迁移旧 .NET 项目时启用；普通 C# 开发无需常驻升级助手。 |
| 1 | CodeGeeX + Codex | CodeGeeX 在实际日志中以 `*` 激活。日常 Profile 先只保留主要使用的 AI 助手，另一套在需要时启用，再对比；没有证据证明其中任意一套单独导致了这次卡死。 |
| 2 | HTML/CSS Class Completion、Path Intellisense、Auto Close Tag | 本机三者都在启动日志中以 `*` 激活。Python/论文 Profile 中无需常驻，前端 Profile 再按实际缺少的功能加入。 |
| 2 | Git Graph、WakaTime | 都记录了 `*` 激活。有使用需求可保留在独立 Profile；优先确认内置 Git 历史/终端命令是否够用，以及是否需要持续统计。 |
| 2 | Markdown Preview Enhanced、Marp、Mermaid Preview | 打开 Markdown 会加载多套预览能力；普通编辑先保留内置预览与 Markdown All in One，需要幻灯片/特殊语法时再启用对应项。 |
| 2 | Excel Viewer + Rainbow CSV | 日志显示纯文本也能触发查看器。CSV 日常先保留 Rainbow CSV，Excel 表格查看器按需启用。 |
| 3 | 两个 GitHub Actions 插件、多个 Docker 工具 | Actions 默认选官方 `github.vscode-github-actions`。Docker 默认选当前 `ms-azuretools.vscode-containers`；旧 `vscode-docker` 在本机已是依赖它的包装扩展。`docker.docker` 提供另一套能力，先按需选用，不能简单视为同一插件。 |
| 3 | Python/C++/Java/Remote 扩展包 | 不把所有语言包铺在默认 Profile。扩展包本身可能很轻，卸载包也不等于其子扩展已卸载；重点是实际启用的子扩展。 |
| 3 | Fix Checksums / APC / animations 残留 | 目前安装清单没有 APC 与动画插件，但设置有旧的注入入口。删除无效设置可避免后续误加载；单凭残留不能断定当前仍有注入或它就是性能问题。 |

Python/Pylance、Jupyter、Ruff、LaTeX Workshop、Tinymist 仍是科研核心能力，不因插件多就全部关掉。
纯语法/主题扩展通常也不值得仅凭名字列为首要嫌疑。

## Debian 已采用的整理

一键软件安装现在默认请求 **7 个通用扩展 + 12 个科研扩展，共 19 个**，取代此前平铺的 54 个。
Python、Jupyter、SSH 本身会带扩展依赖或子包，因此实际安装数量可能超过 19。
这不是“在旧安装里自动删到 19 个”：已有的其他扩展会保留，需要手动禁用或使用新的空 Profile。

| 组 | 内容 |
| --- | --- |
| `core` | 中文界面、Macchiato、Material Icons、EditorConfig、TOML、YAML、Markdown All in One |
| `research`（默认） | Python / Pylance / Debugpy / 环境管理、Ruff、Jupyter / Keymap / Renderers、LaTeX Workshop、Tinymist、Rainbow CSV、Remote SSH |
| `cpp`、`rust`、`go`、`java`、`web`、`dotnet` | 各语言的 LSP、调试、构建或格式化能力；Java 不带 Azure 迁移，.NET 不带升级助手 |
| `remote` | Remote SSH、Dev Containers、Container Tools；Debian 不自动装 WSL 扩展 |
| `codex` | 可选 Codex IDE 扩展（可能自动带入语音子包）；CLI 已由软件安装脚本单独安装 |
| `marp`、`markdown-preview`、`mermaid` | 三种单独选择的写作扩展，按需要安装 |
| `tools`、`wakatime` | 可选查看器/项目工具与独立的活动统计 |

```bash
# 仅预览默认扩展，不调用 code、不改配置
bash ~/myconfig/debian/install-vscode.sh --dry-run

# 列出可选组
bash ~/myconfig/debian/install-vscode.sh --list

# 在默认 Profile 安装日常科研组
bash ~/myconfig/debian/install-vscode.sh

# 首次创建科研 Profile：窗口出现后关闭，--wait 返回后再安装
code --profile Research --new-window --wait
bash ~/myconfig/debian/install-vscode.sh --bundle research --profile Research

# 为其他任务分别创建 Profile，同样先关闭新窗口再安装
code --profile CPP --new-window --wait
bash ~/myconfig/debian/install-vscode.sh --bundle cpp --profile CPP
code --profile Web --new-window --wait
bash ~/myconfig/debian/install-vscode.sh --bundle web --profile Web
bash ~/myconfig/debian/install-vscode.sh --bundle research --bundle remote --bundle codex --profile Research

# 只装最小通用扩展
bash ~/myconfig/debian/install-vscode.sh --bundle core --profile Minimal

code --profile Research --new-window ~/your-project
```

**给同一个默认 Profile 追加所有组会重新变成大而全的环境。** 新建 Profile 不会自动复制默认 Profile 的设置；
主题、字体、快捷键可以在“配置文件 / Profiles”界面选择从原 Profile 复制，扩展单独选择，
也可以在新 Profile 的用户设置中手动设置。不要把整个旧扩展清单同步回刚建好的轻量 Profile。
VS Code 打开不存在的命名 Profile 时会创建空 Profile，但扩展安装 CLI 只接受已存在的 Profile。
脚本会先检查，缺失时在安装前退出并提示创建命令，不会自动弹出窗口或重启编辑器。
脚本只调用标准扩展安装接口、合并重复 ID，保留依赖；安装失败会继续其他项并最终返回非零，
逐项记录在 `~/.local/state/myconfig-debian/failed-vscode-extensions.txt`。
[官方 Profile 说明](https://code.visualstudio.com/docs/configure/profiles)

Debian 用户设置还作了这些调整：

- `cmake.configureOnOpen` / `makefile.configureOnOpen` 设为 `false`，需要时主动配置；
  Go 工具不再自动后台更新，改为需要时运行更新命令。
- `git.autofetch: false`，减少后台网络活动；这不等于解决了已证明的启动 CPU 阻塞。
- 终端 GPU 渲染由 `off` 恢复 `auto`，为滚动提供硬件加速机会；这是终端设置，不是整个 VS Code 的 GPU 开关。
- 保留 Pylance `standard` 检查和默认索引能力，显式写出 `openFilesOnly`。
  **该诊断模式本来就是本机默认值，不能把它宣称为新的提速。** 不默认使用会削弱补全能力的 light 模式。
- 清除 APC/动画/vibrancy、旧游戏/办公扩展等残留设置与不再默认安装的 Code Runner 执行器表。
  这些清理主要是恢复配置可维护性，不能给无效设置本身记上实测提速。
- 保留 LaTeX 的 `onSave` 构建与 `onFailed` 清理；本机 Windows 目前为 `onBuilt`，
  每次成功构建后删除中间文件，会增加下一次编译的工作量，但与首次打开 VS Code 是不同问题。

## 本机 Windows 的操作顺序

本机是 Scoop 便携版，实际用户设置在：

```text
%USERPROFILE%\scoop\persist\vscode\data\user-data\User\settings.json
```

`scoop\apps\vscode\current\data` 链接到相同的持久目录。
不要误改通常教程中的 `%APPDATA%\Code\User\settings.json`。

1. 保存文件并关闭所有 VS Code 窗口。先以相同项目、相同文件标签做正常启动，再完整关闭，执行
   `code --disable-extensions --new-window` 后从菜单打开同一项目，比较响应。
   该标志只对这次新窗口生效，不卸载或永久禁用扩展。若差异明显，优先继续扩展排查；
   无扩展仍慢，再检查工作区大小、磁盘、驱动与已注入的程序文件。
2. 在旧 Profile 的扩展界面优先“禁用（工作区）”Azure 迁移 / .NET 升级，以及当前项目不用的语言、预览与统计扩展。
   每次只改一组并重新加载窗口，记录结果。Windows 专用的 WSL 不应因 Debian 不需要它就从 Windows 一律删除。
3. 最推荐为科研建一个新的空 Profile。下面在 **myconfig 仓库根目录的 PowerShell** 执行，
   首行先创建/打开 `Research-Fast`；窗口出现后关闭，命令返回后会继续安装，再重新打开。
   不会删改原 Profile：

```powershell
code --profile 'Research-Fast' --new-window --wait
$profileReady = $LASTEXITCODE -eq 0
if (-not $profileReady) { throw 'Could not open Research-Fast profile' }
$lists = @('.\debian\vscode-extensions.txt', '.\debian\vscode\extensions\research.txt')
$ids = Get-Content -LiteralPath $lists | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } | Sort-Object -Unique
$failed = @()
foreach ($id in $ids) {
    code --profile 'Research-Fast' --install-extension $id
    if ($LASTEXITCODE -ne 0) { $failed += $id }
}
if ($failed.Count) { Write-Warning ('Failed: ' + ($failed -join ', ')) }
code --profile 'Research-Fast' --new-window
```

原 Windows 设置有绝对路径、远程连接信息，**不要整份复制 Debian 设置覆盖 Windows，也不要提交本机原始设置和日志**。
设置同步如果带回旧 Profile 的全部扩展，会抵消隔离效果。新 Profile 默认没有旧的字体、快捷键和主题设置，
先只迁移必要项；`workbench.colorTheme: "Catppuccin Macchiato"` 和
`workbench.iconTheme: "material-icon-theme"` 可直接在设置界面选择。

4. 对照修改少量设置，先在原设置旁保存一份备份。无屏幕阅读器需求时可将本机的
   `editor.accessibilitySupport: "on"` 改成 `"auto"`；有无障碍需求则保留。
   不要复制 `/usr/bin/python3` 等 Debian 路径到 Windows：

```jsonc
{
    "cmake.configureOnOpen": false,
    "makefile.configureOnOpen": false,
    "git.autofetch": false,
    "go.toolsManagement.autoUpdate": false,
    "terminal.integrated.gpuAcceleration": "auto",
    "latex-workshop.latex.autoClean.run": "onFailed"
}
```

这些设置优先减少自动任务、网络与重复编译，不承诺每项都会缩短冷启动。
若终端开启 GPU 后出现花屏，再单独调整终端设置，避免直接禁用整个窗口的硬件加速。
旧 `apc.*`、`animations.*`、`vscode_vibrancy.*`、`vscode_custom_css.imports` 可在确认不再用它们后删除。
其中本机的 custom CSS 导入还指向 Linux 绝对路径。若程序文件仍被旧补丁改过，应先备份持久用户数据，
再用 Scoop 的正常重新安装流程恢复官方程序；仅删配置不一定能还原已改过的程序文件。

## 大型 AI 项目的额外调整

打开一个具体项目，不要直接打开整个主目录或同时包含数据集、模型缓存、所有实验的上层目录。
先看文件数量与所在目录再排除；[workspace-settings.example.jsonc](workspace-settings.example.jsonc)
是按项目选用的模板，不能不经检查就覆盖现有 `.vscode/settings.json`。

- `files.watcherExclude` 只减轻 VS Code 文件监视；`search.exclude` 影响搜索；
  `python.analysis.exclude` 影响 Pylance 的扫描范围，三者不是同一个开关。
- 环境、数据集、checkpoint、实验输出适合排除；源码与测试保留。
  被排除的 Python 文件若仍被源码导入，语言服务仍可能分析。
- 本机没有设置全工作区诊断，Pylance 已是 `openFilesOnly`；不要把相同值重复设置当成修复。
  索引量仍大时先缩小项目根目录与排除范围，再考虑限制索引或临时 light 模式并接受功能折损。
- 特别大的 Notebook 先清理不需要的历史输出，在独立窗口打开；它属于文档/渲染负载，需要与扩展宿主卡顿分别比较。

[Pylance 模式说明](https://github.com/microsoft/pylance-release/blob/main/docs/settings/python_analysis_languageServerMode.md)

## 如何确认实际改善

在相同项目、文件标签、Profile 下重复 3 次完整退出后启动，区分首次更新/下载与稳定状态；
空窗口与项目窗口分别比较。不要用 `Measure-Command { code . }` 的 CLI 返回时间代替 GUI 准备完成时间。

通过命令面板运行：

- `Developer: Startup Performance`：查看启动阶段计时。
- `Developer: Show Running Extensions`：查看哪些扩展实际激活、激活原因和时间；
  激活时间不能覆盖所有后续后台任务，继续使用该页面的录制功能获取 CPU profile。
- `Help: Start Extension Bisect`：按每轮是否仍卡顿，让 VS Code 二分定位；完成后恢复原状态。
- `Developer: Open Process Explorer`：区分 renderer、extension host 与独立语言服务进程的占用。

若卡在首次启动，先完整退出 VS Code，再运行 `code --prof-startup`，使用官方故障排查流程保存分析文件。
Profile 可能含项目路径或代码，不直接公开上传。只有完成禁用对比和 CPU 采样，才能给出有证据的耗时排名。
本轮没有声称调整后已经达到某个启动秒数。
[VS Code 官方性能排查](https://github.com/microsoft/vscode/wiki/Performance-Issues)
