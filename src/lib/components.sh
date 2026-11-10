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

# ---------------------------------------------------------------------------
# Removal on uncheck (S7)
#
# Only a component that was RECORDED as selected and is no longer selected is
# removed: components_removed compares the recorded selection with the new one
# (both normalized, so herdr-app counts as herdr-core too). A selection that
# was never recorded removes nothing. The plan lists only what exists now;
# nothing outside the component's own paths is ever in it. Every removal is
# guarded: no path is built from an empty variable, symlinks are removed only
# when they point into this repo, and recursive removal is limited to the
# Herdr app directory.
# Requires lib/detect.sh and lib/dotbot.sh (dotbot_managed_links,
# dotbot_filter_repo_owned_links).
# ---------------------------------------------------------------------------

COMPONENT_TAB="$(printf '\t')"

# components_removed <old ids> <new ids> — print the ids (normalized, fixed
# order) in <old> that are not in <new>. Nothing when <old> is empty.
components_removed() {
    # shellcheck disable=SC2086
    _cr_old="$(components_normalize ${1:-})"
    # shellcheck disable=SC2086
    _cr_new=" $(components_normalize ${2:-}) "
    _cr_out=""
    for _cr_id in ${_cr_old}; do
        case "${_cr_new}" in
            *" ${_cr_id} "*) ;;
            *) _cr_out="${_cr_out:+${_cr_out} }${_cr_id}" ;;
        esac
    done
    printf '%s\n' "${_cr_out}"
}

# _components_plan_add <id> <kind> <value> — one plan line (tab separated).
# Kinds: formula, cask, link, dir, file.
_components_plan_add() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

# _components_brew_has <formula|cask> <name> — succeed when brew has it installed.
_components_brew_has() {
    command -v brew >/dev/null 2>&1 || return 1
    brew list "--$1" "$2" >/dev/null 2>&1
}

# _components_filter_prefix <prefix> — stdin lines that start with <prefix> and
# continue past it.
_components_filter_prefix() {
    while IFS= read -r _cfp_l; do
        case "${_cfp_l}" in
            "$1"?*) printf '%s\n' "${_cfp_l}" ;;
        esac
    done
}

# _components_plan_links <id> <dir prefix> — add the symlinks under <prefix>
# that Dotbot declares and that point into this repo (others are never listed).
_components_plan_links() {
    _cpl_id="$1"
    _cpl_prefix="$2"
    [ -n "${_cpl_prefix}" ] || return 0
    if ! command -v dotbot_managed_links >/dev/null 2>&1 \
        || ! command -v dotbot_filter_repo_owned_links >/dev/null 2>&1; then
        log_warn "Dotbot helpers unavailable; symlinks under ${_cpl_prefix} are left in place"
        return 0
    fi
    _cpl_declared="$(dotbot_managed_links 2>/dev/null)" || {
        log_warn "Could not list the Dotbot links; symlinks under ${_cpl_prefix} are left in place"
        return 0
    }
    _cpl_owned="$(printf '%s\n' "${_cpl_declared}" | _components_filter_prefix "${_cpl_prefix}" | dotbot_filter_repo_owned_links)" || _cpl_owned=""
    printf '%s\n' "${_cpl_owned}" | while IFS= read -r _cpl_l; do
        [ -n "${_cpl_l}" ] || continue
        _components_plan_add "${_cpl_id}" link "${_cpl_l}"
    done
}

# _components_plan_file <id> <path> — add <path> when it is a regular file or a
# symlink (the official installer's shape); warn and skip anything else.
_components_plan_file() {
    if [ -L "$2" ] || [ -f "$2" ]; then
        _components_plan_add "$1" file "$2"
    elif [ -e "$2" ]; then
        log_warn "$2 is not a regular file or symlink (not the official installer's file); left in place"
    fi
}

# components_removal_plan <new ids> <removed id>... — print the removal plan:
# "<id><TAB><kind><TAB><value>" lines for what exists now. <new ids> decides
# whether the shared Herdr config link may go (only when no Herdr component
# stays selected).
components_removal_plan() {
    _crp_new="${1:-}"
    shift
    _crp_home="${HOME:?components_removal_plan: HOME required}"
    _crp_os="$(detect_os)"
    _crp_data="${XDG_DATA_HOME:-${_crp_home}/.local/share}"
    _crp_bin="${_crp_home}/.local/bin"
    _crp_herdr=0
    for _crp_id in "$@"; do
        case "${_crp_id}" in
            tmux)
                for _crp_p in tmux gitmux; do
                    if _components_brew_has formula "${_crp_p}"; then
                        _components_plan_add tmux formula "${_crp_p}"
                    fi
                done
                _components_plan_links tmux "${_crp_home}/.config/tmux/"
                ;;
            herdr-tui)
                _crp_herdr=1
                if _components_brew_has formula herdr; then
                    _components_plan_add herdr-tui formula herdr
                fi
                ;;
            herdr-app)
                _crp_herdr=1
                if [ "${_crp_os}" = macos ]; then
                    if _components_brew_has cask herdr-app; then
                        _components_plan_add herdr-app cask herdr-app
                    fi
                elif [ "${_crp_os}" = linux ]; then
                    if [ -d "${_crp_data}/herdr-app" ] || [ -L "${_crp_data}/herdr-app" ]; then
                        _components_plan_add herdr-app dir "${_crp_data}/herdr-app"
                    fi
                    for _crp_f in "${_crp_bin}/herdr-app" \
                        "${_crp_data}/applications/herdr-app.desktop" \
                        "${_crp_data}"/icons/hicolor/*/apps/herdr-app.png \
                        "${_crp_data}"/icons/hicolor/*/apps/herdr-app.svg \
                        "${_crp_data}/pixmaps/herdr-app.png"; do
                        _components_plan_file herdr-app "${_crp_f}"
                    done
                fi
                ;;
            herdr-core)
                _crp_herdr=1
                _components_plan_file herdr-core "${_crp_bin}/herdr-core"
                _components_plan_file herdr-core "${_crp_bin}/hc"
                ;;
            ghostty)
                if [ "${_crp_os}" = macos ] && _components_brew_has cask ghostty; then
                    _components_plan_add ghostty cask ghostty
                fi
                _components_plan_links ghostty "${_crp_home}/.config/ghostty/"
                ;;
        esac
    done
    if [ "${_crp_herdr}" -eq 1 ]; then
        case " ${_crp_new} " in
            *" herdr-tui "* | *" herdr-core "* | *" herdr-app "*) ;;
            *) _components_plan_links herdr-config "${_crp_home}/.config/herdr/" ;;
        esac
    fi
}

# components_plan_ids <plan> — print the plan's component ids, once each, in
# plan order (the shared Herdr config link is the pseudo-component herdr-config).
components_plan_ids() {
    printf '%s\n' "$1" | while IFS="${COMPONENT_TAB}" read -r _cpi_c _cpi_rest; do
        [ -n "${_cpi_c}" ] && printf '%s\n' "${_cpi_c}"
    done | awk '!seen[$0]++'
}

# components_removal_lines <plan> <id> — print the confirmation lines for <id>
# (one per package call or path), exactly what components_remove will do.
components_removal_lines() {
    _crl_formulas=""
    while IFS="${COMPONENT_TAB}" read -r _crl_c _crl_k _crl_v; do
        [ "${_crl_c}" = "$2" ] || continue
        case "${_crl_k}" in
            formula) _crl_formulas="${_crl_formulas:+${_crl_formulas} }${_crl_v}" ;;
            cask) printf 'brew uninstall --cask %s\n' "${_crl_v}" ;;
            link) printf 'remove symlink %s\n' "${_crl_v}" ;;
            dir) printf 'remove directory %s\n' "${_crl_v}" ;;
            file) printf 'remove file %s\n' "${_crl_v}" ;;
        esac
    done <<EOF
$1
EOF
    if [ -n "${_crl_formulas}" ]; then
        printf 'brew uninstall %s\n' "${_crl_formulas}"
    fi
}

# _components_rm <kind> <path> — guarded removal of one planned path.
_components_rm() {
    case "$2" in
        /?*) ;;
        *) log_warn "Refusing to remove '$2' (not an absolute path)"; return 1 ;;
    esac
    case "$1" in
        link)
            _crm_owned="$(printf '%s\n' "$2" | dotbot_filter_repo_owned_links)" || return 1
            if [ "${_crm_owned}" != "$2" ]; then
                log_warn "$2 no longer points into this repo; left in place"
                return 1
            fi
            rm -f -- "$2"
            ;;
        file)
            if [ -L "$2" ] || [ -f "$2" ]; then
                rm -f -- "$2"
            fi
            ;;
        dir)
            case "$2" in
                /?*/herdr-app) ;;
                *) log_warn "Refusing to remove '$2' (not a herdr-app directory)"; return 1 ;;
            esac
            if [ -L "$2" ]; then
                rm -f -- "$2"
            elif [ -d "$2" ]; then
                rm -rf -- "$2"
            fi
            ;;
        *) return 1 ;;
    esac
}

# components_remove <plan> <id>... — carry out the plan, component by component.
# A failing step warns and the rest still runs; the status is non-zero when any
# step failed.
components_remove() {
    _cm_plan="$1"
    shift
    _cm_fail=0
    for _cm_id in "$@"; do
        _cm_formulas=""
        while IFS="${COMPONENT_TAB}" read -r _cm_c _cm_k _cm_v; do
            [ "${_cm_c}" = "${_cm_id}" ] || continue
            case "${_cm_k}" in
                formula) _cm_formulas="${_cm_formulas:+${_cm_formulas} }${_cm_v}" ;;
                cask)
                    if brew uninstall --cask "${_cm_v}" >/dev/null; then
                        log_ok "brew uninstall --cask ${_cm_v}"
                    else
                        log_warn "brew uninstall --cask ${_cm_v} failed"
                        _cm_fail=1
                    fi
                    ;;
                link | file | dir)
                    if _components_rm "${_cm_k}" "${_cm_v}"; then
                        log_ok "removed ${_cm_v}"
                    else
                        log_warn "could not remove ${_cm_v}"
                        _cm_fail=1
                    fi
                    ;;
            esac
        done <<EOF
${_cm_plan}
EOF
        if [ -n "${_cm_formulas}" ]; then
            # shellcheck disable=SC2086
            if brew uninstall ${_cm_formulas} >/dev/null; then
                log_ok "brew uninstall ${_cm_formulas}"
            else
                log_warn "brew uninstall ${_cm_formulas} failed"
                _cm_fail=1
            fi
        fi
    done
    return "${_cm_fail}"
}
