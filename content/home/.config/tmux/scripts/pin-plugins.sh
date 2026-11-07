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
# checkout already at its pin is not touched (no network).
#
# It fails closed, because TPM loads every @plugin line it finds, pinned or not:
#   - an @plugin line is accepted as `set|set-option -g @plugin 'owner/repo'`
#     (single or double quotes, leading whitespace, optional trailing
#     `# comment`); any other non-comment line with an @plugin token is reported;
#   - the line above it must be `# pin <40 lowercase hex>`;
#   - owner/repo is limited to [A-Za-z0-9._-]+/[A-Za-z0-9._-]+ without a `.` or
#     `..` segment, so the destination stays inside the plugins dir;
#   - a plugin it just cloned whose pin cannot be checked out is removed again
#     (a pre-existing checkout is never removed).
# Each problem is one `pin-plugins:` line on stderr and the exit status is 1;
# the other plugins are still handled.

conf=${1:?usage: pin-plugins.sh <tmux.conf> <plugins-dir>}
dir=${2:?usage: pin-plugins.sh <tmux.conf> <plugins-dir>}
base=${DOTS_TMUX_PLUGIN_BASE_URL:-https://github.com}
status=0

fail() {
    printf 'pin-plugins: %s: %s\n' "$1" "$2" >&2
    status=1
}

# valid_spec <spec> — owner/repo with safe characters and no dot segments.
valid_spec() {
    case $1 in
        */*/* | /* | */ | '' | *[!A-Za-z0-9._/-]*) return 1 ;;
        */*) ;;
        *) return 1 ;;
    esac
    case ${1%%/*} in . | .. | '') return 1 ;; esac
    case ${1#*/} in . | .. | '') return 1 ;; esac
    return 0
}

pin_one() {
    spec=$1 sha=$2
    valid_spec "$spec" || { fail "$spec" "not a plain owner/repo plugin name"; return; }
    dest=$dir/${spec#*/}

    case $sha in
        '') fail "$spec" "no '# pin <sha>' line above its @plugin"; return ;;
        *[!0-9a-f]*) fail "$spec" "pin '$sha' is not a lowercase hex commit"; return ;;
    esac
    [ ${#sha} -eq 40 ] || { fail "$spec" "pin '$sha' is not 40 characters"; return; }

    fresh=
    if [ ! -e "$dest" ]; then
        mkdir -p "$dir" &&
            GIT_TERMINAL_PROMPT=0 git clone -q "$base/$spec" "$dest" 2>/dev/null ||
            { fail "$spec" "cannot clone $base/$spec"; return; }
        fresh=1
    fi
    [ "$(git -C "$dest" rev-parse HEAD 2>/dev/null)" = "$sha" ] && return

    git -C "$dest" cat-file -e "$sha^{commit}" 2>/dev/null ||
        GIT_TERMINAL_PROMPT=0 git -C "$dest" fetch -q origin 2>/dev/null
    if ! git -C "$dest" checkout -q --detach "$sha" 2>/dev/null; then
        # A fresh clone sits on the branch tip: leaving it would let TPM load
        # unpinned code, so take it away again.
        [ -n "$fresh" ] && rm -rf "$dest"
        fail "$spec" "cannot check out pinned commit $sha in $dest${fresh:+ (fresh clone removed)}"
        return
    fi
    git -C "$dest" submodule update -q --init --recursive 2>/dev/null || true
}

# parse_plugin <trimmed line> — print the spec of an accepted @plugin line.
parse_plugin() {
    printf '%s\n' "$1" | sed -n -E "s/^set(-option)?[[:space:]]+-g[[:space:]]+@plugin[[:space:]]+('([^']*)'|\"([^\"]*)\")[[:space:]]*(#.*)?\$/\\3\\4/p"
}

sha=
while IFS= read -r line || [ -n "$line" ]; do
    # trim leading and trailing whitespace
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    case $line in
        '# pin '*)
            sha=${line#'# pin '}
            sha=${sha%"${sha##*[![:space:]]}"} ;;
        '#'*)
            sha= ;;
        *)
            case " $line " in
                *[[:space:]]@plugin[[:space:]]*)
                    spec=$(parse_plugin "$line")
                    if [ -n "$spec" ]; then
                        pin_one "$spec" "$sha"
                    else
                        fail "cannot parse @plugin line" "$line"
                    fi ;;
            esac
            sha= ;;
    esac
done <"$conf"

exit "$status"
