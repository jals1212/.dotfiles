# Dotfiles — zsh bootstrap
# Loads on every shell start (login, interactive, scripts). Keep it minimal.
# Standard zsh autoload files live at $HOME; config fragments live under
# $XDG_CONFIG_HOME/zsh and are sourced explicitly from .zshrc.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
