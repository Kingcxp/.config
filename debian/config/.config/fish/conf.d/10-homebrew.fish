# Make Homebrew tools available in Fish, including a custom existing prefix.
set -l brew_prefix /home/linuxbrew/.linuxbrew
set -l state_dir "$HOME/.local/state"
if set -q XDG_STATE_HOME; and test -n "$XDG_STATE_HOME"
    set state_dir "$XDG_STATE_HOME"
end
if test -r "$state_dir/myconfig-debian/brew-prefix"
    read brew_prefix < "$state_dir/myconfig-debian/brew-prefix"
end
if test -x "$brew_prefix/bin/brew"
    "$brew_prefix/bin/brew" shellenv fish | source
    fish_add_path --prepend "$brew_prefix/opt/node@22/bin"
end
