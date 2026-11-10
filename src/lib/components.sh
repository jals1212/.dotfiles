# shellcheck shell=sh
# lib/components.sh — which terminal components ./dots installs
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/theme.sh (local state).
#
# The selection is machine-local, like the prompt engine and the font: it is
# recorded as DOTS_COMPONENTS in ~/.config/zsh/local.zsh, a space-separated
# list of ids in the fixed order of COMPONENT_IDS. An empty selection is
# recorded as `none`, so "chose nothing" differs from "never recorded" (no
# DOTS_COMPONENTS line). The repo itself never changes when choosing.

COMPONENT_IDS="tmux herdr-tui herdr-core herdr-app ghostty"
COMPONENT_NONE="none"
# "a>b" rules, newline-separated: selecting a also selects b. The Herdr app
# installer brings the core, so the core is never installed on its own then.
COMPONENT_IMPLIES="herdr-app>herdr-core"

# component_label <id> — print the one-line checklist label for <id>.
component_label() {
    case "${1:-}" in
        tmux)       printf 'tmux + gitmux\n' ;;
        herdr-tui)  printf 'Herdr TUI (brew formula)\n' ;;
        herdr-core) printf 'Herdr core (official installer)\n' ;;
        herdr-app)  printf 'Herdr app (desktop, brings the core)\n' ;;
        ghostty)    printf 'Ghostty (macOS cask)\n' ;;
        *) return 1 ;;
    esac
}

# components_validate <id> — succeed when <id> is a known component.
components_validate() {
    _cv_id="${1:?components_validate: id required}"
    for _cv_known in ${COMPONENT_IDS}; do
        [ "${_cv_id}" = "${_cv_known}" ] && return 0
    done
    log_error "Unknown component '${_cv_id}'. Supported: ${COMPONENT_IDS}"
    return 1
}

# components_normalize [id...] — print the known ids among the arguments, once
# each, with implied ids added, in the fixed order of COMPONENT_IDS.
components_normalize() {
    _cn_state=" $* "
    while IFS='>' read -r _cn_from _cn_to; do
        [ -n "${_cn_from}" ] || continue
        case "${_cn_state}" in
            *" ${_cn_from} "*) _cn_state="${_cn_state}${_cn_to} " ;;
        esac
    done <<EOF
${COMPONENT_IMPLIES}
EOF
    _cn_out=""
    for _cn_id in ${COMPONENT_IDS}; do
        case "${_cn_state}" in
            *" ${_cn_id} "*) _cn_out="${_cn_out:+${_cn_out} }${_cn_id}" ;;
        esac
    done
    printf '%s\n' "${_cn_out}"
}

# components_recorded — print the recorded value (ids or `none`), or nothing
# when no selection was ever recorded.
components_recorded() {
    dots_local_get DOTS_COMPONENTS 2>/dev/null || printf ''
}

# components_selected — print the selected ids (normalized); nothing when the
# selection is `none` or was never recorded.
components_selected() {
    _cs_rec="$(components_recorded)"
    [ "${_cs_rec}" = "${COMPONENT_NONE}" ] && return 0
    # shellcheck disable=SC2086
    components_normalize ${_cs_rec}
}

# components_current — print the selection, or `none` when it is empty.
components_current() {
    _cc_sel="$(components_selected)"
    printf '%s\n' "${_cc_sel:-${COMPONENT_NONE}}"
}

# components_has <id> — succeed when <id> is selected.
components_has() {
    case " $(components_selected | tr '\n' ' ') " in
        *" ${1:?components_has: id required} "*) return 0 ;;
    esac
    return 1
}

# components_has_any <id>... — succeed when at least one of the ids is selected.
components_has_any() {
    for _cha_id in "$@"; do
        components_has "${_cha_id}" && return 0
    done
    return 1
}

# components_apply [id...] — validate every id, then record the normalized
# selection (`none` for no ids). Nothing is written when an id is unknown.
components_apply() {
    for _ca_id in "$@"; do
        components_validate "${_ca_id}" || return 1
    done
    _ca_sel="$(components_normalize "$@")"
    dots_local_set DOTS_COMPONENTS "${_ca_sel:-${COMPONENT_NONE}}"
}
