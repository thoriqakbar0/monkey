#!/bin/zsh

emulate -L zsh
setopt errexit nounset pipefail

config_root=${XDG_CONFIG_HOME:-$HOME/.config}
install_root="$config_root/monkey"
project_root=${0:A:h:h}
zsh_source_file="$project_root/shell/monkey.zsh"
bash_source_file="$project_root/shell/monkey.bash"
zsh_installed_file="$install_root/monkey.zsh"
bash_installed_file="$install_root/monkey.bash"
zdot_root=${ZDOTDIR:-$HOME}
zshrc="$zdot_root/.zshrc"
zsh_source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh"'
bash_source_line='source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"'
bashrc="$HOME/.bashrc"
bash_profile="$HOME/.bash_profile"

command install -d -m 0755 -- "$install_root" "$zdot_root"
command install -m 0644 -- "$zsh_source_file" "$zsh_installed_file"
command install -m 0644 -- "$bash_source_file" "$bash_installed_file"

function append_source_line() {
  local file=$1 line=$2
  if [[ ! -e $file ]]; then
    : >| "$file"
  fi

  if ! command grep -Fqx -- "$line" "$file"; then
    if [[ -s $file ]]; then
      print >> "$file"
    fi
    print -r -- "$line" >> "$file"
  fi
}

append_source_line "$zshrc" "$zsh_source_line"
append_source_line "$bashrc" "$bash_source_line"
append_source_line "$bash_profile" "$bash_source_line"
