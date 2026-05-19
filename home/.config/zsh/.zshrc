# Dotfiles — ZSH
# Theme: DOTS_THEME/DOTS_FLAVOR (via Oh My Posh)

# ── Zinit ────────────────────────────────────────────
# Sourced from Homebrew (Brewfile: brew "zinit"). HOMEBREW_PREFIX is exported
# by `brew shellenv` in .zshenv. Setting ZINIT[BIN_DIR] before sourcing
# tells zinit its source lives at the brew prefix, suppressing the
# self-clone into ~/.local/share/zinit/zinit.git/.
: "${HOMEBREW_PREFIX:=$(command -v brew >/dev/null 2>&1 && brew --prefix 2>/dev/null)}"
for _zinit_dir in "${HOMEBREW_PREFIX}/opt/zinit" /opt/homebrew/opt/zinit /usr/local/opt/zinit /home/linuxbrew/.linuxbrew/opt/zinit; do
  if [[ -f "${_zinit_dir}/zinit.zsh" ]]; then
    typeset -gA ZINIT
    ZINIT[BIN_DIR]="${_zinit_dir}"
    source "${_zinit_dir}/zinit.zsh"
    break
  fi
done
unset _zinit_dir

# ── History ──────────────────────────────────────────
# Atuin is the history source of truth. Keep native zsh history ephemeral.
HISTSIZE=0
SAVEHIST=0
unset HISTFILE
setopt hist_ignore_space

# ── Aliases, functions, keymaps ──────────────────────
# Load first so later plugins can add tool-specific bindings without resets.
# Modules live next to this file in $ZDOTDIR (set by ~/.zshenv).
[[ -f "$ZDOTDIR/aliases.zsh" ]]   && source "$ZDOTDIR/aliases.zsh"
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"
[[ -f "$ZDOTDIR/keymaps.zsh" ]]   && source "$ZDOTDIR/keymaps.zsh"

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
autoload -Uz compinit && compinit
zinit cdreplay -q

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab

# ── Oh My Posh ───────────────────────────────────────
zinit ice has"oh-my-posh"
zinit light "$ZDOTDIR/plugins/oh-my-posh"

# ── Zoxide ───────────────────────────────────────────
zinit ice has"zoxide"
zinit light "$ZDOTDIR/plugins/zoxide"

# ── Mise ─────────────────────────────────────────────
zinit ice has"mise"
zinit light "$ZDOTDIR/plugins/mise"

# ── Atuin ────────────────────────────────────────────
zinit ice has"atuin"
zinit light "$ZDOTDIR/plugins/atuin"

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
