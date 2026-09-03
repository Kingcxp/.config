# fish shell 配置 — 与 nixos_kingcq/home-manager/fish.nix 保持一致

# 基础环境变量
export MICRO_TRUECOLOR=1
export EDITOR=nvim

# oh-my-posh 提示符（Catppuccin Macchiato 定制主题）
if type -q oh-my-posh
    oh-my-posh init fish --config ~/.config/fish/oh-my-posh/catppuccin-macchiato.omp.json | source
end

# zoxide 智能目录跳转（z）
if type -q zoxide
    zoxide init fish | source
end

# 常用别名
alias update="sudo nixos-rebuild switch"
alias ll="ls -la"
alias la="ls -A"
alias lt="eza --tree --level=2"
alias cat="bat"
alias find="fd"

# fisher 插件管理（仅 Arch 等传统发行版；NixOS 请用 home-manager 声明式插件）
if not functions -q fisher && type -q curl
    # 首次安装 fisher（幂等：已有则跳过）
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
        -o /tmp/fisher.fish 2>/dev/null
    and source /tmp/fisher.fish 2>/dev/null
end

# 常用 fisher 插件（已安装则跳过，不重复安装）
if functions -q fisher
    fisher list | grep -q fzf-fish 2>/dev/null; or fisher install PatrickF1/fzf.fish 2>/dev/null
    fisher list | grep -q done 2>/dev/null; or fisher install franciscolourenco/done 2>/dev/null
    fisher list | grep -q forgit 2>/dev/null; or fisher install wfxr/forgit 2>/dev/null
end
