#!/bin/sh
# tmux/scripts/pin-plugins.sh — put every TPM plugin at the commit pinned in tmux.conf
#
# usage: pin-plugins.sh <tmux.conf> <plugins-dir>
#
# TPM can only follow a branch (`owner/repo#branch`), never a commit. So the
# `# pin <sha>` line above each `set -g @plugin 'owner/repo'` in tmux.conf is
# the source of truth: this script clones a missing plugin from
# $DOTS_TMUX_PLUGIN_BASE_URL (default https://github.com) and checks out the
# pin when the checkout is anywhere else, before TPM loads the plugins. A
# checkout already at its pin is not touched (no network). Failures are
# reported on stderr, one `pin-plugins:` line per plugin, and the exit status
# is 1; the other plugins are still handled.

conf=${1:?usage: pin-plugins.sh <tmux.conf> <plugins-dir>}
dir=${2:?usage: pin-plugins.sh <tmux.conf> <plugins-dir>}
base=${DOTS_TMUX_PLUGIN_BASE_URL:-https://github.com}
status=0

fail() {
    printf 'pin-plugins: %s: %s\n' "$1" "$2" >&2
    status=1
}

pin_one() {
    spec=$1 sha=$2
    dest=$dir/${spec##*/}

    case $sha in
        '' ) fail "$spec" "no '# pin <sha>' line above its @plugin"; return ;;
        *[!0-9a-f]* ) fail "$spec" "pin '$sha' is not a lowercase hex commit"; return ;;
    esac
    [ ${#sha} -eq 40 ] || { fail "$spec" "pin '$sha' is not 40 characters"; return; }

    if [ ! -e "$dest" ]; then
        mkdir -p "$dir" &&
            GIT_TERMINAL_PROMPT=0 git clone -q "$base/$spec" "$dest" 2>/dev/null ||
            { fail "$spec" "cannot clone $base/$spec"; return; }
    fi
    [ "$(git -C "$dest" rev-parse HEAD 2>/dev/null)" = "$sha" ] && return

    git -C "$dest" cat-file -e "$sha^{commit}" 2>/dev/null ||
        GIT_TERMINAL_PROMPT=0 git -C "$dest" fetch -q origin 2>/dev/null
    git -C "$dest" checkout -q --detach "$sha" 2>/dev/null ||
        { fail "$spec" "cannot check out pinned commit $sha in $dest"; return; }
    git -C "$dest" submodule update -q --init --recursive 2>/dev/null || true
}

sha=
while IFS= read -r line || [ -n "$line" ]; do
    case $line in
        '# pin '*)
            sha=${line#'# pin '} ;;
        "set -g @plugin '"*)
            spec=${line#"set -g @plugin '"}
            spec=${spec%%"'"*}
            pin_one "$spec" "$sha"
            sha= ;;
        *)
            sha= ;;
    esac
done <"$conf"

exit "$status"
