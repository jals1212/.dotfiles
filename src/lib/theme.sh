#!/bin/sh
# lib/theme.sh — theme-switcher implementation
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/tui.sh, lib/dotbot.sh sourced before (or this file
# sources them lazily when REPO_ROOT is set).

# ---------------------------------------------------------------------------
# Internal: ensure log helpers are available
# ---------------------------------------------------------------------------
if ! command -v log_error >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/log.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/log.sh"
    fi
fi

if ! command -v dotbot_theme_apply >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/dotbot.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/dotbot.sh"
    fi
fi

# ---------------------------------------------------------------------------
# Internal helpers (prefixed _th_)
# ---------------------------------------------------------------------------

# _th_index_path — print the absolute path to themes/index.yaml
_th_index_path() {
    printf '%s/content/themes/index.yaml' "${REPO_ROOT:?REPO_ROOT required}"
}

# _th_tmux_conf_path — print the absolute path to the repo tmux.conf
_th_tmux_conf_path() {
    printf '%s/content/home/.config/tmux/tmux.conf' "${REPO_ROOT:?REPO_ROOT required}"
}

# _th_manifest_path — print the absolute path to manifest.json
_th_manifest_path() {
    printf '%s/manifest.json' "${REPO_ROOT:?REPO_ROOT required}"
}

# _th_tmux_fence_count <file>
#   Print the number of opening-fence lines (# >>> dots:theme >>>) in <file>.
_th_tmux_fence_count() {
    _tfc_file="${1:?_th_tmux_fence_count: file required}"
    if [ ! -f "${_tfc_file}" ]; then
        printf '0'
        return 0
    fi
    _tfc_n="$(grep -c '# >>> dots:theme >>>' "${_tfc_file}" 2>/dev/null || printf '0')"
    printf '%s' "${_tfc_n}"
}

# _th_write_manifest <theme> <flavor>
#   Atomically write the slim manifest to REPO_ROOT/manifest.json.
_th_write_manifest() {
    _twm_theme="${1:?_th_write_manifest: theme required}"
    _twm_flavor="${2:?_th_write_manifest: flavor required}"
    _twm_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _twm_target="$(_th_manifest_path)"
    _twm_tmp="${_twm_target}.tmp"

    printf '{\n  "version": "3.0.0",\n  "theme": "%s",\n  "flavor": "%s",\n  "applied_at": "%s"\n}\n' \
        "${_twm_theme}" "${_twm_flavor}" "${_twm_ts}" > "${_twm_tmp}"
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

    # --- Step 3: Tmux fence management ---
    _ta_fence_open='# >>> dots:theme >>>'
    _ta_fence_close='# <<< dots:theme <<<'
    _ta_theme_line="set -g @ukiyo-theme '${_ta_theme}/${_ta_flavor}'"

    _ta_fence_count="$(_th_tmux_fence_count "${_ta_tmux_conf}")"

    if [ "${_ta_fence_count}" -eq 0 ]; then
        # Insert fences before first "set -g " or "run-shell " line, or at end.
        # Use awk to avoid multiple individual >> redirects.
        _ta_tmp="${_ta_tmux_conf}.theme.tmp"
        awk \
            -v open="${_ta_fence_open}" \
            -v close="${_ta_fence_close}" \
            -v content="${_ta_theme_line}" \
            '
            !inserted && /^(set -g |run-shell )/ {
                print open
                print content
                print close
                inserted=1
            }
            { print }
            END { if (!inserted) { print open; print content; print close } }
            ' "${_ta_tmux_conf}" > "${_ta_tmp}"
        mv "${_ta_tmp}" "${_ta_tmux_conf}"
        _ta_fence_count="$(_th_tmux_fence_count "${_ta_tmux_conf}")"
    fi

    # Sanity check before rewrite
    if [ "${_ta_fence_count}" -ne 1 ]; then
        log_error "Duplicate tmux theme fences detected (count=${_ta_fence_count}); aborting rewrite to avoid corruption"
        return 1
    fi

    # Rewrite fence content in-place using awk (portable BSD+GNU)
    _ta_tmp="${_ta_tmux_conf}.theme.tmp"
    awk \
        -v open="${_ta_fence_open}" \
        -v close="${_ta_fence_close}" \
        -v content="${_ta_theme_line}" \
        '
        $0 == open  { print; in_fence=1; next }
        $0 == close { print content; print; in_fence=0; next }
        in_fence    { next }
        { print }
        ' "${_ta_tmux_conf}" > "${_ta_tmp}"
    mv "${_ta_tmp}" "${_ta_tmux_conf}"

    # Verify fence integrity after rewrite
    _ta_open_count="$(grep -c '# >>> dots:theme >>>' "${_ta_tmux_conf}" 2>/dev/null || printf '0')"
    _ta_close_count="$(grep -c '# <<< dots:theme <<<' "${_ta_tmux_conf}" 2>/dev/null || printf '0')"
    if [ "${_ta_open_count}" -ne 1 ] || [ "${_ta_close_count}" -ne 1 ]; then
        log_error "Fence integrity check failed after rewrite (open=${_ta_open_count}, close=${_ta_close_count})"
        return 1
    fi

    # --- Step 4: Bat cache rebuild ---
    if command -v bat >/dev/null 2>&1; then
        bat cache --build >/dev/null
    else
        log_warn "bat not installed; skipping bat cache rebuild"
    fi

    # --- Step 5: Tmux server reload ---
    if tmux info >/dev/null 2>&1; then
        tmux source-file "${HOME}/.tmux.conf" 2>/dev/null \
            || tmux source-file "${HOME}/.config/tmux/tmux.conf" 2>/dev/null \
            || log_warn "tmux source-file failed; active sessions may need a manual reload"
    fi

    # --- Step 6: Write manifest ---
    _th_write_manifest "${_ta_theme}" "${_ta_flavor}" || {
        log_error "Failed to write manifest"
        return 1
    }

    log_ok "Theme set: ${_ta_theme}/${_ta_flavor}"
}
