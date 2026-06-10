# Dotfiles — Completions

(( $+functions[zinit] )) || return

# Completion definitions must be loaded before compinit.
zinit light zsh-users/zsh-completions

_zsh_cache_dir="${XDG_CACHE_HOME}/zsh"
[[ -d "$_zsh_cache_dir" ]] || command mkdir -p "$_zsh_cache_dir"
autoload -Uz compinit && compinit -d "$_zsh_cache_dir/zcompdump-${ZSH_VERSION}"
unset _zsh_cache_dir

zinit cdreplay -q

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab
