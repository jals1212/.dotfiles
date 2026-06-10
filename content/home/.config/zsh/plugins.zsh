# Dotfiles — Plugins

(( $+functions[zinit] )) || return

# All plugins load deferred (turbo) just after the first prompt. Slot order
# preserves the required sequence: compinit (0a, completions.zsh) → fzf-tab
# (0b) → autosuggestions → syntax-highlighting (0c, registration order).

# Zoxide
zinit ice wait"0a" lucid has"zoxide"
zinit light "$ZDOTDIR/plugins/zoxide"

# Mise
zinit ice wait"0a" lucid has"mise"
zinit light "$ZDOTDIR/plugins/mise"

# Abbreviations
export ABBR_USER_ABBREVIATIONS_FILE="$ZDOTDIR/abbr.zsh"
zinit ice wait"0b" lucid atload'[[ -f $ABBR_USER_ABBREVIATIONS_FILE ]] && source "$ABBR_USER_ABBREVIATIONS_FILE"'
zinit light olets/zsh-abbr

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
# Autosuggestions normally starts from a precmd hook that has already fired
# by the time turbo loads it, so start it explicitly.
zinit ice wait"0c" lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

zinit ice wait"0c" lucid
zinit light zsh-users/zsh-syntax-highlighting
