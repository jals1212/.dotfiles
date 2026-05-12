# Dotfiles — ZSH
# Theme: Catppuccin Mocha (via Starship)

# ── Zinit ────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# ── Completions ──────────────────────────────────────
autoload -Uz compinit && compinit
zinit cdreplay -q

# ── History ──────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups

# ── Starship ─────────────────────────────────────────
eval "$(starship init zsh)"

# ── Atuin ────────────────────────────────────────────
eval "$(atuin init zsh)"

# ── Zoxide ───────────────────────────────────────────
eval "$(zoxide init zsh)"

# ── Mise ─────────────────────────────────────────────
eval "$(mise activate zsh)"

# ── FZF ──────────────────────────────────────────────
# CATPPUCCIN_FZF_START
export FZF_DEFAULT_OPTS="\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8\
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc\
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8\
--color=selected-bg:#45475a\
--color=border:#585b70,label:#cdd6f4"
# CATPPUCCIN_FZF_END

# ── Source extras ────────────────────────────────────
[[ -f ~/.zalias ]] && source ~/.zalias
[[ -f ~/.zfunc ]] && source ~/.zfunc
[[ -f ~/.zkey ]]  && source ~/.zkey

# ── Auto-start tmux ──────────────────────────────────
function start_if_needed() {
    if [[ $- == *i* ]] && [[ -z "${TMUX}" ]] && [[ -t 1 ]] && [[ -z "${DOTS_NO_TMUX}" ]]; then
        exec tmux
    fi
}
start_if_needed
