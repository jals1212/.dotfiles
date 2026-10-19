# shellcheck shell=sh
# lib/prompt.sh — prompt engine selection (starship | p10k)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/theme.sh (manifest + local state).
#
# The engine choice is machine-local: it lives in ~/.config/zsh/local.zsh
# (written via dots_local_set, sourced from .zshenv) and in the manifest.
# The repo itself never changes when switching prompts.

PROMPT_ENGINES="starship p10k"
PROMPT_DEFAULT_ENGINE="starship"

# prompt_validate <engine>
#   Validate <engine> against the supported prompt engines.
prompt_validate() {
    _pv_engine="${1:?prompt_validate: engine required}"
    for _pv_known in ${PROMPT_ENGINES}; do
        [ "${_pv_engine}" = "${_pv_known}" ] && return 0
    done
    log_error "Unknown prompt engine '${_pv_engine}'. Supported: ${PROMPT_ENGINES}"
    return 1
}

# prompt_current
#   Print the active prompt engine: manifest field first, local.zsh as
#   fallback, then the default. Always succeeds with some engine name.
prompt_current() {
    _pc_engine="$(_th_read_manifest_field prompt 2>/dev/null || printf '')"
    if [ -z "${_pc_engine}" ]; then
        _pc_engine="$(dots_local_get DOTS_PROMPT 2>/dev/null || printf '')"
    fi
    printf '%s\n' "${_pc_engine:-${PROMPT_DEFAULT_ENGINE}}"
}

# prompt_apply <engine>
#   Full prompt apply: validate → local.zsh → manifest → reload marker.
prompt_apply() {
    _pa_engine="${1:?prompt_apply: engine required}"

    prompt_validate "${_pa_engine}" || return 1

    _pa_previous="$(prompt_current)"
    dots_local_set DOTS_PROMPT "${_pa_engine}" || return 1

    # Preserve the active theme/flavor while recording the new engine.
    _pa_pair="$(theme_current 2>/dev/null || printf '')"
    if [ -n "${_pa_pair}" ]; then
        _pa_theme="${_pa_pair%% *}"
        _pa_flavor="${_pa_pair##* }"
        _th_write_manifest "${_pa_theme}" "${_pa_flavor}" "${_pa_engine}" || return 1
    fi

    if [ "${_pa_engine}" != "${_pa_previous}" ]; then
        dots_request_reload
    fi

    return 0
}
