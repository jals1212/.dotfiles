# Dotfiles — Abbreviations

(( $+functions[abbr] )) || return

# Git
abbr -S --quieter --force g=git
abbr git -S --quieter --force ga=add
abbr git -S --quieter --force gaa="add --all"
abbr git -S --quieter --force gb=branch
abbr git -S --quieter --force gba="branch --all"
abbr git -S --quieter --force gbd="branch --delete"
abbr git -S --quieter --force gco=checkout
abbr git -S --quieter --force gcb="checkout -b"
abbr git -S --quieter --force gc="commit --verbose"
abbr git -S --quieter --force gca="commit --verbose --all"
abbr git -S --quieter --force gcmsg="commit --message"
abbr git -S --quieter --force gd=diff
abbr git -S --quieter --force gds="diff --staged"
abbr git -S --quieter --force gf=fetch
abbr git -S --quieter --force gl=pull
abbr git -S --quieter --force gp=push
abbr git -S --quieter --force gpsup="push --set-upstream origin HEAD"
abbr git -S --quieter --force grb=rebase
abbr git -S --quieter --force grba="rebase --abort"
abbr git -S --quieter --force grbc="rebase --continue"
abbr git -S --quieter --force grbi="rebase --interactive"
abbr git -S --quieter --force grh=reset
abbr git -S --quieter --force grs=restore
abbr git -S --quieter --force grst="restore --staged"
abbr git -S --quieter --force gsta="stash push"
abbr git -S --quieter --force gstp="stash pop"
abbr git -S --quieter --force gst=status
abbr git -S --quieter --force gss="status --short"
abbr git -S --quieter --force gsw=switch
abbr git -S --quieter --force gswc="switch --create"

# Tmux
abbr -S --quieter --force tx="tmux new-session -A -s main"
abbr -S --quieter --force txs="tmux new-session -A -s"
abbr -S --quieter --force txa="tmux attach -t"
abbr -S --quieter --force txl="tmux ls"
abbr -S --quieter --force txk="tmux kill-session -t"

# System
abbr -S --quieter --force c=clear
