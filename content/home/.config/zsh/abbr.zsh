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
abbr git -S --quieter --force gwip='add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
abbr git -S --quieter --force gunwip='rev-list --max-count=1 --format="%s" HEAD | grep -q -- "--wip--" && git reset HEAD~1'

# git fetch all — use parallel --jobs when git supports it (>= 2.8)
autoload -Uz is-at-least
if is-at-least 2.8 "${${(s: :)$(git --version 2>/dev/null)}[3]}"; then
  abbr git -S --quieter --force gfa="fetch --all --tags --prune --jobs=10"
else
  abbr git -S --quieter --force gfa="fetch --all --tags --prune"
fi

# Tmux
abbr -S --quieter --force tx="tmux"
abbr -S --quieter --force txs="tmux new-session -A -s"
abbr -S --quieter --force txa="tmux attach -t"
abbr -S --quieter --force txd="tmux detach"
abbr -S --quieter --force txl="tmux ls"
abbr -S --quieter --force txr="tmux rename-session -t"
abbr -S --quieter --force txrw="tmux rename-window -t"
abbr -S --quieter --force txk="tmux kill-session -t"
abbr -S --quieter --force txka="tmux kill-session -t -a"
abbr -S --quieter --force txkw="tmux kill-window -t"
abbr -S --quieter --force txkp="tmux kill-pane -t"
abbr -S --quieter --force txK="tmux kill-server"

# System
abbr -S --quieter --force c=clear
abbr -S --quieter --force x=exit

