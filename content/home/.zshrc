# Dotfiles — ZSH

# ── Config dir ───────────────────────────────────────
# Standard zsh files (.zshrc, .zshenv, .zprofile) live at $HOME. Repo
# fragments and plugins live under $XDG_CONFIG_HOME/zsh/ and are sourced
# explicitly from this file.
_zsh_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# ── Environment ──────────────────────────────────────
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="bat --paging=always"

# ── PATH ─────────────────────────────────────────────
[[ -f "$_zsh_config_dir/paths.zsh" ]] && source "$_zsh_config_dir/paths.zsh"

# ── Zinit ────────────────────────────────────────────
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ── History ──────────────────────────────────────────
# Atuin is the history source of truth. Keep native zsh history ephemeral.
HISTSIZE=0
SAVEHIST=0
unset HISTFILE
setopt hist_ignore_space

# ── Aliases, functions, keymaps ──────────────────────
# Load first so later plugins can add tool-specific bindings without resets.
[[ -f "$_zsh_config_dir/aliases.zsh" ]]   && source "$_zsh_config_dir/aliases.zsh"
[[ -f "$_zsh_config_dir/functions.zsh" ]] && source "$_zsh_config_dir/functions.zsh"
[[ -f "$_zsh_config_dir/keymaps.zsh" ]]   && source "$_zsh_config_dir/keymaps.zsh"

# ── FZF ──────────────────────────────────────────────
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="fd --type d --hidden --strip-cwd-prefix --exclude .git"
fi
# The active fzf theme is written to ~/.config/fzf/themes/dots.sh by `dots install`.
[ -f ~/.config/fzf/themes/dots.sh ] && source ~/.config/fzf/themes/dots.sh

# ── Eza ──────────────────────────────────────────────
# The active eza colors are written to ~/.config/eza/themes/dots.sh by `dots install`.
[ -f ~/.config/eza/themes/dots.sh ] && source ~/.config/eza/themes/dots.sh

# BAT_THEME is constant; the actual palette comes from
# ~/.config/bat/themes/dots.tmTheme (a per-theme dotbot symlink).
export BAT_THEME="dots"

# Completion definitions must be loaded before compinit.
zinit light zsh-users/zsh-completions

# ── Completions ──────────────────────────────────────
autoload -Uz compinit && compinit
zinit cdreplay -q

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab

# ── Starship prompt ──────────────────────────────────
# Starship is a Homebrew binary; initialize directly (no zinit wrapper),
# guarded by command presence so startup never errors when it is absent.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# ── Zoxide ───────────────────────────────────────────
zinit ice has"zoxide"
zinit light "$_zsh_config_dir/plugins/zoxide"

# ── Mise ─────────────────────────────────────────────
zinit ice has"mise"
zinit light "$_zsh_config_dir/plugins/mise"

# ── Atuin ────────────────────────────────────────────
zinit ice has"atuin"
zinit light "$_zsh_config_dir/plugins/atuin"

# ── Abbreviations ───────────────────────────────────
zinit light olets/zsh-abbr
[[ -f "$_zsh_config_dir/abbr.zsh" ]] && source "$_zsh_config_dir/abbr.zsh"

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

# ── tmux: strip leaked terminal reports ─────────────
# Apps run inside tmux (e.g. Neovim) enable color-scheme change
# notifications (DEC private mode 2031). When a tmux session is killed the
# host terminal emits a `\e[?997;1n` theme report that nothing consumes, so
# it lands in the next prompt as literal `997;1n`. A precmd hook runs too
# late — the bytes are already buffered — so wrap tmux instead: once it
# exits, disable the mode and drain any stray report synchronously, before
# the prompt's line editor reads it.
tmux() {
    command tmux "$@"
    local ret=$?
    if [[ -o interactive && -t 0 ]]; then
        printf '\e[?2031l'                                # stop further reports
        local _discard
        while read -s -t 0.2 -k 1 _discard 2>/dev/null; do :; done  # silently drain
    fi
    return $ret
}

# ── Auto-start tmux ──────────────────────────────────
start_if_needed() {
    if [[ $- == *i* ]] && [[ -z "${TMUX}" ]] && [[ -t 1 ]] && [[ -z "${DOTS_NO_TMUX}" ]]; then
        tmux
    fi
}
# start_if_needed
