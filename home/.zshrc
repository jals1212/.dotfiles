# Dotfiles — ZSH
# Theme: DOTS_THEME/DOTS_FLAVOR (via Oh My Posh)

# ── Config dir ───────────────────────────────────────
# Standard zsh files (.zshrc, .zshenv, .zprofile) live at $HOME. Repo
# fragments and plugins live under $XDG_CONFIG_HOME/zsh/ and are sourced
# explicitly from this file.
_zsh_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

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

# Completion definitions must be loaded before compinit.
zinit light zsh-users/zsh-completions

# ── Completions ──────────────────────────────────────
autoload -Uz compinit && compinit
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

# ── Oh My Zsh plugins (snippet-loaded) ───────────────
zinit snippet OMZP::git
zinit snippet OMZP::extract
zinit snippet OMZP::safe-paste
zinit snippet OMZP::copypath
zinit snippet OMZP::copyfile
zinit snippet OMZP::copybuffer
zinit snippet OMZP::fancy-ctrl-z
zinit snippet OMZP::jsontools
zinit snippet OMZP::gh

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
