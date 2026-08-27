#!/bin/zsh

emulate -L zsh
setopt errexit nounset pipefail

config_root=${XDG_CONFIG_HOME:-$HOME/.config}
install_root="$config_root/monkey"
source_file="${0:A:h:h}/shell/monkey.zsh"
installed_file="$install_root/monkey.zsh"
zdot_root=${ZDOTDIR:-$HOME}
zshrc="$zdot_root/.zshrc"
source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh"'

command install -d -m 0755 -- "$install_root" "$zdot_root"
command install -m 0644 -- "$source_file" "$installed_file"

if [[ ! -e $zshrc ]]; then
  : >| "$zshrc"
fi

if ! command grep -Fqx -- "$source_line" "$zshrc"; then
  if [[ -s $zshrc ]]; then
    print >> "$zshrc"
  fi
  print -r -- "$source_line" >> "$zshrc"
fi
