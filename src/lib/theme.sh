#!/bin/sh
# lib/theme.sh — theme-switcher implementation
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/tui.sh, lib/dotbot.sh sourced before (or this file
# sources them lazily when REPO_ROOT is set).

# ---------------------------------------------------------------------------
# Internal: ensure log helpers are available
# ---------------------------------------------------------------------------
if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

if ! command -v log_error >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib log.sh)" ]; then
        # shellcheck disable=SC1091
        . "$(path_src_lib log.sh)"
    fi
fi

if ! command -v dotbot_theme_apply >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib dotbot.sh)" ]; then
        # shellcheck disable=SC1091
        . "$(path_src_lib dotbot.sh)"
    fi
fi

# ---------------------------------------------------------------------------
# Internal helpers (prefixed _th_)
# ---------------------------------------------------------------------------

# _th_index_path — print the absolute path to themes/index.yaml
_th_index_path() {
    path_themes_index
}

# _th_tmux_conf_path — print the absolute path to the repo tmux.conf
_th_tmux_conf_path() {
    path_content_tmux_conf
}

# _th_starship_conf_path — print the absolute path to the repo starship.toml
_th_starship_conf_path() {
    path_content_starship_config
}

# _th_p10k_conf_path — print the absolute path to the repo p10k.zsh
_th_p10k_conf_path() {
    path_content_p10k_config
}

# _th_manifest_path — print the absolute path to manifest.json
_th_manifest_path() {
    path_manifest
}

# _th_fence_count <file>
#   Print the number of opening-fence lines (# >>> dots:theme >>>) in <file>.
#   The dots:theme fence uses '#'-prefixed markers, which are valid comments in
#   both tmux.conf and starship.toml (TOML), so one helper serves both.
_th_fence_count() {
    _tfc_file="${1:?_th_fence_count: file required}"
    if [ ! -f "${_tfc_file}" ]; then
        printf '0'
        return 0
    fi
    _tfc_n="$(grep -c '# >>> dots:theme >>>' "${_tfc_file}" 2>/dev/null || true)"
    _tfc_n="$(printf '%s\n' "${_tfc_n:-0}" | awk 'NR == 1 { print ($0 ~ /^[0-9]+$/ ? $0 : 0); exit }')"
    printf '%s' "${_tfc_n}"
}

# _th_apply_fence <file> <content_line> <insert_anchor_ere>
#   Ensure exactly one dots:theme fence in <file> with its body set to
#   <content_line>. When no fence exists, insert one before the first line
#   matching <insert_anchor_ere> (or at EOF). Returns non-zero on duplicate
#   fences or a post-rewrite integrity failure.
_th_apply_fence() {
    _af_file="${1:?_th_apply_fence: file required}"
    _af_content="${2:?_th_apply_fence: content required}"
    _af_anchor="${3:?_th_apply_fence: anchor required}"
    _af_open='# >>> dots:theme >>>'
    _af_close='# <<< dots:theme <<<'

    _af_count="$(_th_fence_count "${_af_file}")"
    if [ "${_af_count}" -eq 0 ]; then
        _af_tmp="${_af_file}.theme.tmp"
        awk \
            -v fence_open="${_af_open}" \
            -v fence_close="${_af_close}" \
            -v content="${_af_content}" \
            -v anchor="${_af_anchor}" \
            '
            !inserted && $0 ~ anchor {
                print fence_open; print content; print fence_close; inserted = 1
            }
            { print }
            END { if (!inserted) { print fence_open; print content; print fence_close } }
            ' "${_af_file}" > "${_af_tmp}"
        mv "${_af_tmp}" "${_af_file}"
        _af_count="$(_th_fence_count "${_af_file}")"
    fi

    if [ "${_af_count}" -ne 1 ]; then
        log_error "Duplicate dots:theme fences in ${_af_file} (count=${_af_count}); aborting rewrite to avoid corruption"
        return 1
    fi

    _af_tmp="${_af_file}.theme.tmp"
    awk \
        -v fence_open="${_af_open}" \
        -v fence_close="${_af_close}" \
        -v content="${_af_content}" \
        '
        $0 == fence_open  { print; in_fence = 1; next }
        $0 == fence_close { print content; print; in_fence = 0; next }
        in_fence    { next }
        { print }
        ' "${_af_file}" > "${_af_tmp}"
    mv "${_af_tmp}" "${_af_file}"

    _af_open_n="$(_th_fence_count "${_af_file}")"
    _af_close_n="$(grep -c '# <<< dots:theme <<<' "${_af_file}" 2>/dev/null || true)"
    _af_close_n="$(printf '%s\n' "${_af_close_n:-0}" | awk 'NR == 1 { print ($0 ~ /^[0-9]+$/ ? $0 : 0); exit }')"
    if [ "${_af_open_n}" -ne 1 ] || [ "${_af_close_n}" -ne 1 ]; then
        log_error "Fence integrity check failed for ${_af_file} (open=${_af_open_n}, close=${_af_close_n})"
        return 1
    fi
    return 0
}

# _th_write_manifest <theme> <flavor> [prompt]
#   Atomically write the slim manifest to REPO_ROOT/manifest.json.
#   When [prompt] is omitted, the current manifest value is preserved, falling
#   back to the engine named by the dots:prompt fence in prompt.zsh.
_th_write_manifest() {
    _twm_theme="${1:?_th_write_manifest: theme required}"
    _twm_flavor="${2:?_th_write_manifest: flavor required}"
    _twm_prompt="${3:-}"
    _twm_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _twm_target="$(_th_manifest_path)"
    _twm_tmp="${_twm_target}.tmp"

    if [ -z "${_twm_prompt}" ]; then
        _twm_prompt="$(_th_read_manifest_field prompt 2>/dev/null || printf '')"
    fi
    if [ -z "${_twm_prompt}" ] && [ -f "$(path_content_zsh_prompt)" ]; then
        _twm_prompt="$(sed -n 's/^_dots_prompt_engine="\([^"]*\)".*/\1/p' "$(path_content_zsh_prompt)" | head -1)"
    fi
    _twm_prompt="${_twm_prompt:-starship}"

    printf '{\n  "version": "3.1.0",\n  "theme": "%s",\n  "flavor": "%s",\n  "prompt": "%s",\n  "applied_at": "%s"\n}\n' \
        "${_twm_theme}" "${_twm_flavor}" "${_twm_prompt}" "${_twm_ts}" > "${_twm_tmp}"
    mv "${_twm_tmp}" "${_twm_target}"
}

# _th_read_manifest_field <field>
#   Extract a single field from manifest.json.
#   Prints the value on stdout; returns non-zero if not found.
_th_read_manifest_field() {
    _trmf_field="${1:?_th_read_manifest_field: field required}"
    _trmf_manifest="$(_th_manifest_path)"

    if [ ! -f "${_trmf_manifest}" ]; then
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        _trmf_val="$(jq -r --arg f "${_trmf_field}" '.[$f] // empty' "${_trmf_manifest}" 2>/dev/null)"
    else
        # Portable grep/sed fallback for the simple {"key": "value"} schema
        _trmf_val="$(grep "\"${_trmf_field}\"" "${_trmf_manifest}" \
            | sed 's/.*"'"${_trmf_field}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
            | head -1)"
    fi

    if [ -z "${_trmf_val}" ]; then
        return 1
    fi
    printf '%s' "${_trmf_val}"
}

# ---------------------------------------------------------------------------
# theme_validate <theme> <flavor>
#   Validate <theme> and <flavor> against themes/index.yaml.
#   Prints log_error and returns 1 on failure; returns 0 on success.
# ---------------------------------------------------------------------------
theme_validate() {
    _tv_theme="${1:?theme_validate: theme required}"
    _tv_flavor="${2:?theme_validate: flavor required}"
    _tv_index="$(_th_index_path)"

    if [ ! -f "${_tv_index}" ]; then
        log_error "themes/index.yaml not found at ${_tv_index}"
        return 1
    fi

    # Parse themes/index.yaml with awk.
    # Structure is fixed:
    #   themes:
    #     <theme>:
    #       flavors: [f1, f2, ...]
    # Strategy: look for the theme key, then extract the flavors list.

    # Step 1: check theme exists as a key under "themes:"
    _tv_theme_found="$(awk -v theme="${_tv_theme}" '
        /^themes:/ { in_themes=1; next }
        in_themes && /^  [a-zA-Z]/ {
            # Extract key name (strip trailing colon and spaces)
            key=$0
            gsub(/^[[:space:]]+/, "", key)
            gsub(/:.*/, "", key)
            if (key == theme) { print "yes"; exit }
        }
    ' "${_tv_index}")"

    if [ "${_tv_theme_found}" != "yes" ]; then
        _tv_valid_themes="$(awk '
            /^themes:/ { in_themes=1; next }
            in_themes && /^  [a-zA-Z]/ {
                key=$0
                gsub(/^[[:space:]]+/, "", key)
                gsub(/:.*/, "", key)
                printf "%s ", key
            }
        ' "${_tv_index}")"
        log_error "Unknown theme '${_tv_theme}'. Valid themes: ${_tv_valid_themes}"
        return 1
    fi

    # Step 2: check flavor exists in that theme's flavors list
    _tv_flavor_found="$(awk -v theme="${_tv_theme}" -v flavor="${_tv_flavor}" '
        /^themes:/ { in_themes=1; next }
        in_themes && /^  [a-zA-Z]/ {
            key=$0
            gsub(/^[[:space:]]+/, "", key)
            gsub(/:.*/, "", key)
            in_target=(key == theme)
        }
        in_target && /flavors:/ {
            # Flavors are on same line: flavors: [f1, f2, f3]
            line=$0
            gsub(/.*\[/, "", line)
            gsub(/\].*/, "", line)
            # line is now: "f1, f2, f3"
            n=split(line, arr, /,[[:space:]]*/);
            for (i=1; i<=n; i++) {
                gsub(/^[[:space:]]+/, "", arr[i])
                gsub(/[[:space:]]+$/, "", arr[i])
                if (arr[i] == flavor) { print "yes"; exit }
            }
        }
    ' "${_tv_index}")"

    if [ "${_tv_flavor_found}" != "yes" ]; then
        _tv_valid_flavors="$(awk -v theme="${_tv_theme}" '
            /^themes:/ { in_themes=1; next }
            in_themes && /^  [a-zA-Z]/ {
                key=$0
                gsub(/^[[:space:]]+/, "", key)
                gsub(/:.*/, "", key)
                in_target=(key == theme)
            }
            in_target && /flavors:/ {
                line=$0
                gsub(/.*\[/, "", line)
                gsub(/\].*/, "", line)
                printf "%s", line
                exit
            }
        ' "${_tv_index}")"
        log_error "Unknown flavor '${_tv_flavor}' for theme '${_tv_theme}'. Valid flavors: ${_tv_valid_flavors}"
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# theme_current
#   Print the active <theme> <flavor> pair from manifest.json.
#   Returns 0 on success, non-zero if manifest is absent or unparseable.
# ---------------------------------------------------------------------------
theme_current() {
    _tc_manifest="$(_th_manifest_path)"

    if [ ! -f "${_tc_manifest}" ]; then
        log_error "no active theme; run ./dots theme <theme> <flavor> or ./dots update"
        return 1
    fi

    _tc_theme="$(_th_read_manifest_field theme)" || {
        log_error "no active theme; run ./dots theme <theme> <flavor> or ./dots update"
        return 1
    }
    _tc_flavor="$(_th_read_manifest_field flavor)" || {
        log_error "no active theme; run ./dots theme <theme> <flavor> or ./dots update"
        return 1
    }

    if [ -z "${_tc_theme}" ] || [ -z "${_tc_flavor}" ]; then
        log_error "no active theme; run ./dots theme <theme> <flavor> or ./dots update"
        return 1
    fi

    printf '%s %s\n' "${_tc_theme}" "${_tc_flavor}"
}

# ---------------------------------------------------------------------------
# theme_apply <theme> <flavor>
#   Full theme apply: validate → dotbot → tmux fence → bat cache → manifest.
#   Returns 0 on success, non-zero on any failure.
# ---------------------------------------------------------------------------
theme_apply() {
    _ta_theme="${1:?theme_apply: theme required}"
    _ta_flavor="${2:?theme_apply: flavor required}"
    _ta_tmux_conf="$(_th_tmux_conf_path)"

    # --- Step 1: Validate ---
    theme_validate "${_ta_theme}" "${_ta_flavor}" || return 1

    # --- Step 2: Dotbot per-theme run ---
    dotbot_theme_apply "${_ta_theme}" "${_ta_flavor}" || return 1

    # --- Step 3: tmux fence (theme marker rewritten in place) ---
    _th_apply_fence "${_ta_tmux_conf}" \
        "set -g @ukiyo-theme '${_ta_theme}/${_ta_flavor}'" \
        '^(set -g |run-shell )' || return 1

    # --- Step 3b: starship fence (active palette selected in place) ---
    # Starship has no external-theme include, so the active palette is chosen by
    # a single `palette = "<theme>_<flavor>"` line inside the same dots:theme
    # fence; the per-theme palettes all live in the one starship.toml.
    _ta_starship_conf="$(_th_starship_conf_path)"
    if [ -f "${_ta_starship_conf}" ]; then
        _th_apply_fence "${_ta_starship_conf}" \
            "palette = \"${_ta_theme}_${_ta_flavor}\"" \
            '^[[]' || return 1
    fi

    # --- Step 3c: p10k fence (active palette selected in place) ---
    # Same approach as starship: every palette lives in the one p10k.zsh and
    # the active one is named by a single fenced assignment.
    _ta_p10k_conf="$(_th_p10k_conf_path)"
    if [ -f "${_ta_p10k_conf}" ]; then
        _th_apply_fence "${_ta_p10k_conf}" \
            "_dots_p10k_palette=\"${_ta_theme}_${_ta_flavor}\"" \
            '^typeset' || return 1
    fi

    # --- Step 4: Bat cache rebuild ---
    if command -v bat >/dev/null 2>&1; then
        bat cache --build >/dev/null
    else
        log_warn "bat not installed; skipping bat cache rebuild"
    fi

    # --- Step 5: Tmux server reload ---
    if tmux info >/dev/null 2>&1; then
        tmux source-file "$(path_home_tmux_conf)" 2>/dev/null \
            || tmux source-file "$(path_home_tmux_config)" 2>/dev/null \
            || log_warn "tmux source-file failed; active sessions may need a manual reload"
    fi

    # --- Step 6: Write manifest ---
    _th_write_manifest "${_ta_theme}" "${_ta_flavor}" || {
        log_error "Failed to write manifest"
        return 1
    }

    log_ok "Theme set: ${_ta_theme}/${_ta_flavor}"
}
