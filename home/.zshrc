# Dotfiles — ZSH
# Theme: DOTS_THEME/DOTS_FLAVOR (via Oh My Posh)

# ── Config dir ───────────────────────────────────────
# Standard zsh files (.zshrc, .zshenv, .zprofile) live at $HOME. Repo
# fragments and plugins live under $XDG_CONFIG_HOME/zsh/ and are sourced
# explicitly from this file.
_zsh_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# ── Zinit ────────────────────────────────────────────
# Upstream-recommended install: self-managed source + data dir under
# ${XDG_DATA_HOME}/zinit. zinit is a plugin manager — it owns its own
# state by design; trying to point it at a brew install (or any other
# external source path) breaks its data-dir bookkeeping. Just let it run.
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "${ZINIT_HOME}" ]]; then
  mkdir -p "$(dirname "${ZINIT_HOME}")"
  git clone https://github.com/zdharma-continuum/zinit.git "${ZINIT_HOME}"
fi
source "${ZINIT_HOME}/zinit.zsh"

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
# The active fzf theme is written to ~/.config/fzf/theme.sh by `dots install`.
[ -f ~/.config/fzf/theme.sh ] && source ~/.config/fzf/theme.sh

# ── Eza ──────────────────────────────────────────────
# The active eza colors are written to ~/.config/eza/colors.sh by `dots install`.
[ -f ~/.config/eza/colors.sh ] && source ~/.config/eza/colors.sh

# Completion definitions must be loaded before compinit.
zinit light zsh-users/zsh-completions

# ── Completions ──────────────────────────────────────
# `compinit -i` silently skips insecure entries (e.g. brew's group-writable
# /opt/homebrew/opt) instead of prompting on every shell start.
autoload -Uz compinit && compinit -i
zinit cdreplay -q

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab

# ── Oh My Posh ───────────────────────────────────────
zinit ice has"oh-my-posh"
zinit light "$_zsh_config_dir/plugins/oh-my-posh"

# ── Zoxide ───────────────────────────────────────────
zinit ice has"zoxide"
zinit light "$_zsh_config_dir/plugins/zoxide"

# ── Mise ─────────────────────────────────────────────
zinit ice has"mise"
zinit light "$_zsh_config_dir/plugins/mise"

# ── Atuin ────────────────────────────────────────────
zinit ice has"atuin"
zinit light "$_zsh_config_dir/plugins/atuin"

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting

# ── Auto-start tmux ──────────────────────────────────
function start_if_needed() {
    if [[ $- == *i* ]] && [[ -z "${TMUX}" ]] && [[ -t 1 ]] && [[ -z "${DOTS_NO_TMUX}" ]]; then
        tmux new-session -A -s main
    fi
}
start_if_needed
