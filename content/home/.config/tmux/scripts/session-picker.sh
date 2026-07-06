#!/bin/sh
# tmux/scripts/session-picker.sh — fzf tree picker: sessions + nested windows

{
    tmux list-sessions -F '#S' | while read -r session; do
        echo "▼ ${session}"
        tmux list-windows -t "${session}" -F '  ⦿ #S:#I #W'
    done
} | fzf --reverse --no-border | awk '{print $2}' | xargs -r tmux switch-client -t
