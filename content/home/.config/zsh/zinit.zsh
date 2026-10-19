# Dotfiles — Zinit

_zinit_root="${XDG_DATA_HOME}/zinit"
_zinit_entry="${_zinit_root}/zinit.git/zinit.zsh"
# Pinned zinit commit for fresh installs; bump deliberately.
_zinit_pin="6c9ac1c4bc9bcaede64cb473759ac2c5b9187f98"

if [[ ! -f "$_zinit_entry" ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$_zinit_root" && command chmod g-rwX "$_zinit_root"
    command git clone https://github.com/zdharma-continuum/zinit "$_zinit_root/zinit.git" && \
        command git -C "$_zinit_root/zinit.git" checkout --quiet "$_zinit_pin" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

if [[ -f "$_zinit_entry" ]]; then
    # Skip zinit's zi/zpl/zplg/zini aliases; zi belongs to zoxide
    typeset -gA ZINIT
    ZINIT[NO_ALIASES]=1
    source "$_zinit_entry"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit
fi

unset _zinit_root _zinit_entry _zinit_pin
