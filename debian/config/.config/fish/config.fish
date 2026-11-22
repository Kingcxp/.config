# Fish configuration for Debian.

# 基础环境变量
export MICRO_TRUECOLOR=1
export EDITOR=nvim
set --export LANG zh_CN.UTF-8
set --export LANGUAGE zh_CN:en_US
if set -q XDG_RUNTIME_DIR; and test -f "$HOME/.config/systemd/user/docker.service"
    set --export DOCKER_HOST "unix://$XDG_RUNTIME_DIR/docker.sock"
end

set --export BUN_INSTALL "$HOME/.bun"
fish_add_path -p ~/.bun/bin
fish_add_path -p ~/.local/bin

# oh-my-posh 提示符（clean-detailed 主题）
if type -q oh-my-posh
    oh-my-posh init fish --config ~/.config/fish/oh-my-posh/clean-detailed.omp.json | source
end

# zoxide 智能目录跳转（z）
if type -q zoxide
    zoxide init fish | source
end

if type -q direnv
    direnv hook fish | source
end

# Debian names these executables batcat and fdfind.
alias update="sudo apt update; and sudo apt upgrade"
alias ll="ls -la"
alias la="ls -A"
alias lt="eza --tree --level=2"
if type -q batcat
    alias cat="batcat"
end
if type -q fdfind
    alias fd="fdfind"
end
