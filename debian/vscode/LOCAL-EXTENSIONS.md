# 本机扩展逐项建议（2026-11-21）

来源：本机 VS Code 扩展 CLI、去重后的扩展注册信息与已安装 package.json。共 101 个不同 ID。
版本是检查时的本机版本，不是 Debian 版本锁定。只记录扩展公开元数据，没有复制用户设置、连接地址或原始日志。
“全局启动事件”仅指清单声明的 `*` / `onStartupFinished`，不表示已测量耗时。
标为 `—` 的扩展仍可能因文件类型、工作区扫描或其他扩展调用而在启动时加载。
完整的实测依据、分组方法与优化步骤见 [README.md](README.md)。

| 扩展 ID | 本机版本 | 用途 | 全局启动事件 | 建议 |
| --- | --- | --- | --- | --- |
| `aaron-bond.better-comments` | 3.2.0 | 注释着色 | `onStartupFinished` | 专用项目 Profile 按需；不进入科研默认集 |
| `adpyke.codesnap` | 1.3.4 | 代码截图 | `—` | 按需：tools Profile / 组 |
| `alefragnani.project-manager` | 13.1.0 | 项目切换 | `onStartupFinished` | 按需：tools Profile / 组 |
| `aminer.codegeex` | 2.27.6 | CodeGeeX AI 助手 | `*` | 与主要 AI 助手二选一常驻；本次以 * 激活，先对比禁用效果 |
| `bierner.emojisense` | 0.10.0 | Emoji 补全 | `onStartupFinished` | 专用项目 Profile 按需；不进入科研默认集 |
| `bierner.markdown-emoji` | 0.3.1 | Markdown Emoji 预览 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `catppuccin.catppuccin-vsc` | 3.19.0 | Macchiato 等配色 | `onStartupFinished` | 保留：通用默认集 |
| `charliermarsh.ruff` | 2026.98.0 | Python 检查与格式化 | `—` | 保留：科研默认集 |
| `christian-kohler.path-intellisense` | 2.10.0 | 文件路径补全 | `*` | 路径补全不足时再启用；本次以 * 激活 |
| `codezombiech.gitignore` | 0.10.0 | 生成 gitignore 模板 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `cschlosser.doxdocgen` | 1.4.0 | C/C++ 文档注释 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `dbaeumer.vscode-eslint` | 3.0.34 | JS/TS ESLint | `onStartupFinished` | 按需：web Profile / 组 |
| `docker.docker` | 0.19.1 | Docker DX 工具 | `—` | Docker DX 有单独需求再启用，先与 Container Tools 比较功能 |
| `donjayamanne.python-extension-pack` | 1.7.0 | 第三方 Python 扩展包 | `—` | 不默认使用大包；保留所需子扩展，卸载包不会自动清掉子项 |
| `dustypomerleau.rust-syntax` | 0.6.1 | 额外 Rust 语法 | `—` | 仅确有语法需求时保留；不与 Rust 主语言支持一起默认铺开 |
| `ecmel.vscode-html-css` | 2.0.14 | HTML/CSS 补全 | `onStartupFinished` | 专用项目 Profile 按需；不进入科研默认集 |
| `editorconfig.editorconfig` | 0.18.2 | 跨编辑器格式约定 | `onStartupFinished` | 保留：通用默认集 |
| `esbenp.prettier-vscode` | 12.4.0 | 前端格式化 | `onStartupFinished` | 按需：web Profile / 组 |
| `formulahendry.auto-close-tag` | 0.5.15 | 标签自动闭合 | `*` | 前端 Profile 按需；本次以 * 激活 |
| `george-alisson.html-preview-vscode` | 0.2.5 | HTML 预览 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `github.vscode-github-actions` | 0.32.3 | 官方 GitHub Actions | `—` | 按需：tools Profile / 组 |
| `golang.go` | 0.58.0 | Go / gopls / 调试 | `—` | 按需：go Profile / 组 |
| `grapecity.gc-excelviewer` | 4.2.67 | Excel / CSV 查看器 | `—` | Excel 查看按需；本次纯文本也触发，日常 CSV 先用 Rainbow CSV |
| `hujohner.mc-datapack` | 0.0.5 | Minecraft 数据包工具 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `james-yu.latex-workshop` | 10.20.0 | LaTeX 编译、补全、SyncTeX | `—` | 保留：科研默认集 |
| `jeff-hykin.better-cpp-syntax` | 1.27.1 | 额外 C++ 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `kevinrose.vsc-python-indent` | 1.21.0 | Python 缩进辅助 | `—` | 先用 Python 核心能力验证缩进习惯，再决定是否保留辅助项 |
| `marp-team.marp-vscode` | 3.6.1 | Markdown 幻灯片 | `—` | 按需：marp Profile / 组 |
| `mathiasfrohlich.kotlin` | 1.7.1 | Kotlin 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `me-dutour-mathieu.vscode-github-actions` | 3.0.1 | 另一套 GitHub Actions | `—` | 同类插件先选官方 github.vscode-github-actions |
| `mechatroner.rainbow-csv` | 3.24.1 | CSV 列着色与查询 | `—` | 保留：科研默认集 |
| `mhutchie.git-graph` | 1.30.0 | Git 图形历史 | `*` | 按需：tools Profile / 组 |
| `mikestead.dotenv` | 1.0.1 | 环境文件语法 | `—` | 按需：web Profile / 组 |
| `minecraftcommands.syntax-mcfunction` | 1.0.1 | Minecraft 命令语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `ms-azuretools.vscode-containers` | 2.5.3 | 当前 Container Tools | `—` | 按需：remote Profile / 组 |
| `ms-azuretools.vscode-docker` | 2.0.0 | 旧 Docker 入口的依赖包装 | `—` | 新配置直接请求 vscode-containers；本项已是包装依赖入口 |
| `ms-ceintl.vscode-language-pack-zh-hans` | 1.131.2026090407 | 简体中文界面 | `—` | 保留：通用默认集 |
| `ms-dotnettools.csdevkit` | 3.40.215 | C# 项目、测试工具 | `—` | 按需：dotnet Profile / 组 |
| `ms-dotnettools.csharp` | 2.160.4 | C# 语言服务与调试 | `—` | 按需：dotnet Profile / 组 |
| `ms-dotnettools.upgrade-agent` | 1.1.816 | 旧 .NET 项目升级助手 | `onStartupFinished` | 优先禁用；仅升级旧 .NET 项目时启用 |
| `ms-dotnettools.vscode-dotnet-runtime` | 3.2.0 | 扩展所需 .NET 运行时管理 | `onStartupFinished` | 按需：dotnet Profile / 组 |
| `ms-python.debugpy` | 2026.6.0 | Python 调试器 | `—` | 保留：科研默认集 |
| `ms-python.python` | 2026.10.0 | Python 核心工具 | `—` | 保留：科研默认集 |
| `ms-python.vscode-pylance` | 2026.4.1 | Python 补全、索引、类型诊断 | `—` | 保留：科研默认集 |
| `ms-python.vscode-python-envs` | 1.44.0 | Python 环境发现与管理 | `—` | 保留：科研默认集 |
| `ms-toolsai.jupyter` | 2025.9.1 | Notebook 与交互式 Python | `—` | 保留：科研默认集 |
| `ms-toolsai.jupyter-keymap` | 1.1.2 | Jupyter 快捷键 | `—` | 保留：科研默认集 |
| `ms-toolsai.jupyter-renderers` | 1.3.0 | Notebook 输出渲染 | `—` | 保留：科研默认集 |
| `ms-toolsai.vscode-jupyter-cell-tags` | 0.1.9 | Notebook 单元格标签 | `—` | research 的 Jupyter 扩展包可能自动带入；不按重复项误删 |
| `ms-toolsai.vscode-jupyter-slideshow` | 0.1.6 | Notebook 幻灯片元数据 | `—` | research 的 Jupyter 扩展包可能自动带入；无需求可在 Profile 禁用 |
| `ms-vscode-remote.remote-containers` | 0.475.0 | Dev Containers | `onStartupFinished` | 按需：remote Profile / 组 |
| `ms-vscode-remote.remote-ssh` | 0.124.0 | SSH 远程开发 | `—` | 保留：科研默认集 |
| `ms-vscode-remote.remote-ssh-edit` | 0.87.0 | SSH 配置编辑 | `—` | 随 SSH 依赖按需保留，不单独请求 |
| `ms-vscode-remote.remote-wsl` | 1.104.7 | Windows WSL 开发 | `onStartupFinished` | Windows 确有 WSL 需求时保留；Debian 不默认安装 |
| `ms-vscode-remote.vscode-remote-extensionpack` | 0.26.0 | Remote 大扩展包 | `—` | 按 SSH / Containers / WSL 实际需要选择子扩展 |
| `ms-vscode.cmake-tools` | 1.25.10 | CMake 配置、构建与调试 | `—` | 按需：cpp Profile / 组 |
| `ms-vscode.cpp-devtools` | 0.7.2 | C++ 开发辅助 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `ms-vscode.cpptools` | 1.35.6 | C/C++ 语言服务与调试 | `—` | 按需：cpp Profile / 组 |
| `ms-vscode.cpptools-extension-pack` | 1.5.1 | C++ 大扩展包 | `—` | 改用 cpp 组显式选择子扩展 |
| `ms-vscode.cpptools-themes` | 2.0.0 | C++ 主题包 | `—` | 已有 Macchiato，不默认安装额外主题包 |
| `ms-vscode.hexeditor` | 1.11.1 | 十六进制查看编辑 | `—` | 按需：tools Profile / 组 |
| `ms-vscode.makefile-tools` | 0.12.17 | Make 项目配置与构建 | `—` | 按需：cpp Profile / 组 |
| `ms-vscode.remote-explorer` | 0.5.0 | 远程资源管理视图 | `—` | 随 SSH 依赖按需保留，不单独请求 |
| `ms-vscode.remote-server` | 1.5.4 | 远程隧道入口 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `myriad-dreamin.tinymist` | 0.15.12 | Typst 语言服务与预览 | `—` | 保留：科研默认集 |
| `openai.chatgpt` | 26.1117.41037 | Codex IDE 集成 | `onStartupFinished` | 按需：codex Profile / 组 |
| `openai.codex-audio` | 26.1117.41037 | Codex 语音配套扩展 | `—` | 仅有语音配套需求时保留；不作为科研基础扩展单独请求 |
| `pkief.material-icon-theme` | 5.40.0 | 文件图标主题 | `onStartupFinished` | 保留：通用默认集 |
| `qwtel.sqlite-viewer` | 26.9.1 | SQLite 查看器 | `—` | 按需：tools Profile / 组 |
| `raczzalan.webgl-glsl-editor` | 1.3.9 | WebGL / GLSL | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `redhat.java` | 1.58.0 | Java 语言服务 | `—` | 按需：java Profile / 组 |
| `redhat.vscode-yaml` | 2.0.0 | YAML 语言服务 | `—` | 保留：通用默认集 |
| `rimuruchan.vscode-fix-checksums-next` | 1.4.0 | 修补程序校验提示 | `onStartupFinished` | 不用注入补丁时可移除；它不负责还原已修改的程序文件 |
| `rust-lang.rust-analyzer` | 0.3.3121 | Rust 语言服务 | `—` | 按需：rust Profile / 组 |
| `shahilkumar.docxreader` | 1.4.3 | Word 文档查看 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `shd101wyy.markdown-preview-enhanced` | 0.8.40 | 增强 Markdown 预览 | `onStartupFinished` | 按需：markdown-preview Profile / 组 |
| `slevesque.shader` | 1.1.5 | Shader 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `spgoding.datapack-language-server` | 4.15.0 | Minecraft 数据包语言服务 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `steoates.autoimport` | 1.5.4 | Python 自动导入 | `—` | 默认由 Pylance 负责 Python 导入补全；先禁用重复导入提供器 |
| `stevensona.shader-toy` | 0.11.4 | ShaderToy 工具 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `tamasfe.even-better-toml` | 0.21.2 | TOML 语言服务 | `—` | 保留：通用默认集 |
| `tboox.xmake-vscode` | 2.6.0 | Xmake 构建集成 | `—` | 按需：cpp Profile / 组 |
| `textualize.textual-syntax-highlighter` | 1.3.0 | Textual 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `tobermory.es6-string-html` | 2.17.0 | JS 字符串内 HTML 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `tomoki1207.pdf` | 1.2.2 | 通用 PDF 预览 | `—` | 按需：tools Profile / 组 |
| `twxs.cmake` | 0.0.17 | CMake 语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `uctakeoff.vscode-counter` | 3.8.1 | 代码行统计 | `—` | 专用项目 Profile 按需；不进入科研默认集 |
| `vscjava.migrate-java-to-azure` | 1.24.0 | Java / Python 等项目迁移 Azure | `—` | 优先禁用；本次 Python 工作区也激活，并出现迁移工具注册错误 |
| `vscjava.vscode-gradle` | 3.19.0 | Gradle 集成 | `—` | 按需：java Profile / 组 |
| `vscjava.vscode-java-debug` | 0.60.0 | Java 调试器 | `—` | 按需：java Profile / 组 |
| `vscjava.vscode-java-dependency` | 0.27.7 | Java 项目视图 | `—` | 按需：java Profile / 组 |
| `vscjava.vscode-java-pack` | 0.31.2 | Java 大扩展包 | `—` | 改用 java 组显式选择子扩展 |
| `vscjava.vscode-java-test` | 0.47.0 | Java 测试 | `—` | 按需：java Profile / 组 |
| `vscjava.vscode-maven` | 0.46.0 | Maven 集成 | `—` | 按需：java Profile / 组 |
| `vstirbu.vscode-mermaid-preview` | 2.2.1 | Mermaid 预览 | `onStartupFinished` | 按需：mermaid Profile / 组 |
| `vue.volar` | 3.3.14 | Vue 语言服务 | `—` | 按需：web Profile / 组 |
| `wakatime.vscode-wakatime` | 30.2.1 | 开发活动统计 | `*` | 按需：wakatime Profile / 组 |
| `webfreak.debug` | 0.27.0 | GDB / LLDB 调试集成 | `—` | 按具体调试器选择；不与 cpptools / CodeLLDB 无区别全局堆叠 |
| `yzhang.markdown-all-in-one` | 3.6.3 | Markdown 编辑、目录与快捷键 | `—` | 保留：通用默认集 |
| `zignd.html-css-class-completion` | 1.20.0 | HTML CSS class 补全 | `*` | 前端 Profile 按需；本次以 * 激活，科研 Profile 先禁用 |
| `zixuanwang.linkerscript` | 1.0.4 | 链接器脚本语法 | `—` | 专用项目 Profile 按需；不进入科研默认集 |

默认集保留核心科研能力，其他条目是使用场景建议，不是全部经过 CPU 测试后的性能判定。
CodeLLDB (`vadimcn.vscode-lldb`) 不在本机这 101 项中，但原 NixOS 扩展清单含有它，因此保留在可选 rust 组。
新的分组没有继续默认请求旧清单中的 Code Runner 与 autodocstring；本机当前也没有安装这两项。
