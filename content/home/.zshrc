# Dotfiles — ZSH

# Standard zsh files (.zshrc, .zshenv, .zprofile) live at $HOME. Repo
# fragments and plugins live under $XDG_CONFIG_HOME/zsh/ and are sourced
# explicitly from this file.
_zsh_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Core shell state
[[ -f "$_zsh_config_dir/env.zsh" ]]     && source "$_zsh_config_dir/env.zsh"
[[ -f "$_zsh_config_dir/paths.zsh" ]]   && source "$_zsh_config_dir/paths.zsh"
[[ -f "$_zsh_config_dir/zinit.zsh" ]]   && source "$_zsh_config_dir/zinit.zsh"
[[ -f "$_zsh_config_dir/history.zsh" ]] && source "$_zsh_config_dir/history.zsh"

# User commands and base keymaps load before plugins can add/wrap widgets.
[[ -f "$_zsh_config_dir/aliases.zsh" ]]   && source "$_zsh_config_dir/aliases.zsh"
[[ -f "$_zsh_config_dir/functions.zsh" ]] && source "$_zsh_config_dir/functions.zsh"
[[ -f "$_zsh_config_dir/keymaps.zsh" ]]   && source "$_zsh_config_dir/keymaps.zsh"

# Tool-owned shell entrypoints
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/config.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/config.zsh"
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/eza/config.zsh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/eza/config.zsh"

# Plugin/completion order matters: completions before widget-wrapping plugins.
[[ -f "$_zsh_config_dir/completions.zsh" ]] && source "$_zsh_config_dir/completions.zsh"
[[ -f "$_zsh_config_dir/prompt.zsh" ]]      && source "$_zsh_config_dir/prompt.zsh"
[[ -f "$_zsh_config_dir/plugins.zsh" ]]     && source "$_zsh_config_dir/plugins.zsh"
[[ -f "$_zsh_config_dir/tmux.zsh" ]]        && source "$_zsh_config_dir/tmux.zsh"
