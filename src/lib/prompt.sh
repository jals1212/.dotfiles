# lib/prompt.sh — prompt engine selection (starship | p10k)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/theme.sh (manifest writer).

PROMPT_ENGINES="starship p10k"
PROMPT_DEFAULT_ENGINE="starship"

# _pr_conf_path — print the absolute path to the repo prompt.zsh
_pr_conf_path() {
    path_content_zsh_prompt
}

# _pr_fence_count <file>
#   Print the number of opening-fence lines (# >>> dots:prompt >>>) in <file>.
_pr_fence_count() {
    _pfc_file="${1:?_pr_fence_count: file required}"
    if [ ! -f "${_pfc_file}" ]; then
        printf '0'
        return 0
    fi
    _pfc_n="$(grep -c '# >>> dots:prompt >>>' "${_pfc_file}" 2>/dev/null || true)"
    _pfc_n="$(printf '%s\n' "${_pfc_n:-0}" | awk 'NR == 1 { print ($0 ~ /^[0-9]+$/ ? $0 : 0); exit }')"
    printf '%s' "${_pfc_n}"
}

# _pr_apply_fence <file> <content_line>
#   Ensure exactly one dots:prompt fence in <file> with its body set to
#   <content_line>. Mirrors theme.sh's _th_apply_fence, with prompt markers.
#   Returns non-zero on duplicate fences or a post-rewrite integrity failure.
_pr_apply_fence() {
    _paf_file="${1:?_pr_apply_fence: file required}"
    _paf_content="${2:?_pr_apply_fence: content required}"
    _paf_open='# >>> dots:prompt >>>'
    _paf_close='# <<< dots:prompt <<<'

    _paf_count="$(_pr_fence_count "${_paf_file}")"
    if [ "${_paf_count}" -ne 1 ]; then
        log_error "Expected exactly one dots:prompt fence in ${_paf_file} (count=${_paf_count}); aborting rewrite"
        return 1
    fi

    _paf_tmp="${_paf_file}.prompt.tmp"
    awk \
        -v fence_open="${_paf_open}" \
        -v fence_close="${_paf_close}" \
        -v content="${_paf_content}" \
        '
        $0 == fence_open  { print; in_fence = 1; next }
        $0 == fence_close { print content; print; in_fence = 0; next }
        in_fence    { next }
        { print }
        ' "${_paf_file}" > "${_paf_tmp}"
    mv "${_paf_tmp}" "${_paf_file}"

    _paf_open_n="$(_pr_fence_count "${_paf_file}")"
    _paf_close_n="$(grep -c '# <<< dots:prompt <<<' "${_paf_file}" 2>/dev/null || true)"
    _paf_close_n="$(printf '%s\n' "${_paf_close_n:-0}" | awk 'NR == 1 { print ($0 ~ /^[0-9]+$/ ? $0 : 0); exit }')"
    if [ "${_paf_open_n}" -ne 1 ] || [ "${_paf_close_n}" -ne 1 ]; then
        log_error "Fence integrity check failed for ${_paf_file} (open=${_paf_open_n}, close=${_paf_close_n})"
        return 1
    fi
    return 0
}

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
#   Print the active prompt engine: manifest field first, prompt.zsh fence as
#   fallback, then the default. Always succeeds with some engine name.
prompt_current() {
    _pc_engine="$(_th_read_manifest_field prompt 2>/dev/null || printf '')"
    if [ -z "${_pc_engine}" ]; then
        _pc_engine="$(prompt_fence_engine)"
    fi
    printf '%s\n' "${_pc_engine:-${PROMPT_DEFAULT_ENGINE}}"
}

# prompt_fence_engine
#   Print the engine named by the dots:prompt fence in the repo prompt.zsh,
#   or the default when the fence/file is missing.
prompt_fence_engine() {
    _pfe_conf="$(_pr_conf_path)"
    _pfe_engine=""
    if [ -f "${_pfe_conf}" ]; then
        _pfe_engine="$(sed -n 's/^_dots_prompt_engine="\([^"]*\)".*/\1/p' "${_pfe_conf}" | head -1)"
    fi
    printf '%s' "${_pfe_engine:-${PROMPT_DEFAULT_ENGINE}}"
}

# prompt_apply <engine>
#   Full prompt apply: validate → prompt.zsh fence → manifest.
prompt_apply() {
    _pa_engine="${1:?prompt_apply: engine required}"

    prompt_validate "${_pa_engine}" || return 1

    _pa_conf="$(_pr_conf_path)"
    if [ ! -f "${_pa_conf}" ]; then
        log_error "prompt config not found: ${_pa_conf}"
        return 1
    fi
    _pr_apply_fence "${_pa_conf}" "_dots_prompt_engine=\"${_pa_engine}\"" || return 1

    # Preserve the active theme/flavor while recording the new engine.
    _pa_pair="$(theme_current 2>/dev/null || printf '')"
    if [ -n "${_pa_pair}" ]; then
        _pa_theme="${_pa_pair%% *}"
        _pa_flavor="${_pa_pair##* }"
        _th_write_manifest "${_pa_theme}" "${_pa_flavor}" "${_pa_engine}" || return 1
    fi

    return 0
}
