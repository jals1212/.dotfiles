# Dotfiles — Plugins

(( $+functions[zinit] )) || return

# Zoxide
zinit ice has"zoxide"
zinit light "$ZDOTDIR/plugins/zoxide"

# Mise
zinit ice has"mise"
zinit light "$ZDOTDIR/plugins/mise"

# Abbreviations
export ABBR_USER_ABBREVIATIONS_FILE="$ZDOTDIR/abbr.zsh"
zinit light olets/zsh-abbr
[[ -f $ABBR_USER_ABBREVIATIONS_FILE ]] && source $ABBR_USER_ABBREVIATIONS_FILE

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
