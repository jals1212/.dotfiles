# Dotfiles — Plugins

(( $+functions[zinit] )) || return

_zsh_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Zoxide
zinit ice has"zoxide"
zinit light "$_zsh_config_dir/plugins/zoxide"

# Mise
zinit ice has"mise"
zinit light "$_zsh_config_dir/plugins/mise"

# Abbreviations
zinit light olets/zsh-abbr
[[ -f "$_zsh_config_dir/abbr.zsh" ]] && source "$_zsh_config_dir/abbr.zsh"

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
