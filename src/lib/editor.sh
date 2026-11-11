# shellcheck shell=sh
# lib/editor.sh — terminal $EDITOR/$VISUAL selection (nvim | fresh)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/theme.sh (local state),
# lib/components.sh (is the editor's component selected).
#
# The choice is machine-local, like the font: it is recorded as DOTS_EDITOR in
# ~/.config/zsh/local.zsh, and .zshenv exports EDITOR and VISUAL from it
# (default nvim) after sourcing local.zsh. The repo itself never changes. It
# is separate from the components: the components install editors, this picks
# which one the terminal opens.

if ! command -v components_has >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/components.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/components.sh"
    fi
fi

EDITOR_CHOICES="nvim fresh"
EDITOR_DEFAULT="nvim"

# editor_command <editor> — print the command $EDITOR runs for <editor>.
# The Homebrew formula fresh-editor installs a binary named `fresh`.
editor_command() {
    case "${1:-}" in
        nvim)  printf 'nvim\n' ;;
        fresh) printf 'fresh\n' ;;
        *) return 1 ;;
    esac
}

# editor_validate <editor> — succeed when <editor> is a supported choice.
editor_validate() {
    _ev_editor="${1:?editor_validate: editor required}"
    for _ev_known in ${EDITOR_CHOICES}; do
        [ "${_ev_editor}" = "${_ev_known}" ] && return 0
    done
    log_error "Unknown editor '${_ev_editor}'. Supported: ${EDITOR_CHOICES}"
    return 1
}

# editor_recorded — print the recorded editor, or nothing when none was chosen.
editor_recorded() {
    dots_local_get DOTS_EDITOR 2>/dev/null || printf ''
}

# editor_current — print the active editor: the recorded choice or the default.
editor_current() {
    _ec_editor="$(editor_recorded)"
    printf '%s\n' "${_ec_editor:-${EDITOR_DEFAULT}}"
}

# editor_apply <editor>
#   Validate → record DOTS_EDITOR in local.zsh. Warns (never fails) when the
#   editor's component is not selected, since nothing installed it.
editor_apply() {
    _ea_editor="${1:?editor_apply: editor required}"
    editor_validate "${_ea_editor}" || return 1
    dots_local_set DOTS_EDITOR "${_ea_editor}" || return 1
    if command -v components_has >/dev/null 2>&1 && ! components_has "${_ea_editor}"; then
        log_warn "The ${_ea_editor} component is not selected, so ${_ea_editor} may not be installed; run ./dots components to add it"
    fi
    return 0
}
