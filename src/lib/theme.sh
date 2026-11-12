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
        # shellcheck disable=SC1090,SC1091
        . "$(path_src_lib log.sh)"
    fi
fi

if ! command -v dotbot_theme_apply >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib dotbot.sh)" ]; then
        # shellcheck disable=SC1090,SC1091
        . "$(path_src_lib dotbot.sh)"
    fi
fi

if ! command -v components_has >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib components.sh)" ]; then
        # shellcheck disable=SC1090,SC1091
        . "$(path_src_lib components.sh)"
    fi
fi

# ---------------------------------------------------------------------------
# Internal helpers (prefixed _th_)
# ---------------------------------------------------------------------------

# _th_index_path — print the absolute path to themes/index.yaml
_th_index_path() {
    path_themes_index
}

# _th_starship_conf_path — print the absolute path to the repo starship.toml
_th_starship_conf_path() {
    path_content_starship_config
}

# _th_herdr_conf_path — print the absolute path to the repo Herdr config
_th_herdr_conf_path() {
    path_content_herdr_config
}

# _th_manifest_path — print the absolute path to manifest.json
_th_manifest_path() {
    path_manifest
}

# _th_fence_count <file>
#   Print the number of opening-fence lines (# >>> dots:theme >>>) in <file>.
#   The dots:theme fence uses '#'-prefixed markers, which are valid comments
#   in starship.toml (TOML), the only fenced file.
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

# dots_local_set <var> <value>
#   Record a machine-local choice in ~/.config/zsh/local.zsh — a real file in
#   $HOME (never tracked by the repo), sourced from .zshenv. Lines use the
#   guarded form `export VAR="${VAR:-value}"` so a per-shell env override
#   still wins over the persisted value.
dots_local_set() {
    _dls_var="${1:?dots_local_set: variable required}"
    _dls_val="${2:?dots_local_set: value required}"
    _dls_file="$(path_home_zsh_local)"
    _dls_tmp="${_dls_file}.tmp"

    if [ ! -f "${_dls_file}" ]; then
        printf '# Machine-local dots state — written by ./dots; not tracked by the repo.\n' > "${_dls_file}"
    fi
    grep -v "^export ${_dls_var}=" "${_dls_file}" > "${_dls_tmp}" || true
    printf 'export %s="${%s:-%s}"\n' "${_dls_var}" "${_dls_var}" "${_dls_val}" >> "${_dls_tmp}"
    mv "${_dls_tmp}" "${_dls_file}"
}

# dots_local_get <var>
#   Print the persisted value of <var> from local.zsh; non-zero when absent.
dots_local_get() {
    _dlg_var="${1:?dots_local_get: variable required}"
    _dlg_file="$(path_home_zsh_local)"
    [ -f "${_dlg_file}" ] || return 1
    _dlg_val="$(sed -n "s/^export ${_dlg_var}=\"\${${_dlg_var}:-\(.*\)}\"$/\1/p" "${_dlg_file}" | head -1)"
    [ -n "${_dlg_val}" ] || return 1
    printf '%s\n' "${_dlg_val}"
}

# dots_request_reload
#   Drop a marker the interactive `dots` zsh wrapper checks to offer an
#   `exec zsh` once the command finishes.
dots_request_reload() {
    _drr_dir="$(path_dots_state_dir)"
    [ -d "${_drr_dir}" ] || mkdir -p "${_drr_dir}"
    : > "${_drr_dir}/reload-needed"
}

# _th_herdr_theme_name <theme> <flavor>
#   Map dots theme/flavor pairs to Herdr's built-in theme names.
_th_herdr_theme_name() {
    _htn_theme="${1:?_th_herdr_theme_name: theme required}"
    _htn_flavor="${2:?_th_herdr_theme_name: flavor required}"

    case "${_htn_theme}:${_htn_flavor}" in
        kanagawa:lotus) printf 'kanagawa-lotus' ;;
        kanagawa:*) printf 'kanagawa' ;;
        catppuccin:latte) printf 'catppuccin-latte' ;;
        catppuccin:*) printf 'catppuccin' ;;
        *) return 1 ;;
    esac
}

# _th_apply_herdr_theme <theme> <flavor>
#   Rewrite the fenced Herdr [theme].name line in the repo config.
_th_apply_herdr_theme() {
    _aht_theme="${1:?_th_apply_herdr_theme: theme required}"
    _aht_flavor="${2:?_th_apply_herdr_theme: flavor required}"
    _aht_conf="$(_th_herdr_conf_path)"

    [ -f "${_aht_conf}" ] || return 0

    _aht_name="$(_th_herdr_theme_name "${_aht_theme}" "${_aht_flavor}")" || {
        log_error "No Herdr theme mapping for ${_aht_theme}/${_aht_flavor}"
        return 1
    }

    _th_apply_fence "${_aht_conf}" \
        "name = \"${_aht_name}\"" \
        '^auto_switch[[:space:]]*='
}

# _th_check_nvim_link <theme> <flavor>
#   Everything that can make the nvim link step fail, checked (and the link's
#   directory prepared) before theme_apply changes anything: the flavor's
#   palette exists, nothing but a symlink sits at the link path, and the link's
#   directory exists and is writable.
_th_check_nvim_link() {
    _cnl_theme="${1:?_th_check_nvim_link: theme required}"
    _cnl_flavor="${2:?_th_check_nvim_link: flavor required}"
    _cnl_palette="$(path_nvim_palette "${_cnl_theme}" "${_cnl_flavor}")"
    _cnl_link="$(path_content_nvim_theme_link)"

    if [ ! -f "${_cnl_palette}" ]; then
        log_error "Neovim palette not found: ${_cnl_palette}"
        return 1
    fi
    if [ -e "${_cnl_link}" ] && [ ! -L "${_cnl_link}" ]; then
        log_error "${_cnl_link} is not a symlink; refusing to replace it"
        return 1
    fi
    _cnl_dir="$(dirname "${_cnl_link}")"
    [ -d "${_cnl_dir}" ] || mkdir -p "${_cnl_dir}" 2>/dev/null
    if [ ! -d "${_cnl_dir}" ] || [ ! -w "${_cnl_dir}" ]; then
        log_error "${_cnl_dir} is not a writable directory; cannot link the Neovim palette"
        return 1
    fi
}

# _th_apply_nvim_link <theme> <flavor>
#   Point content/home/.config/nvim/lua/dots-theme.lua at the flavor's Neovim
#   palette. Runs the same checks as _th_check_nvim_link first, so it refuses to
#   replace anything that is not a symlink and leaves the existing link
#   untouched when the palette is missing.
_th_apply_nvim_link() {
    _anl_theme="${1:?_th_apply_nvim_link: theme required}"
    _anl_flavor="${2:?_th_apply_nvim_link: flavor required}"
    _th_check_nvim_link "${_anl_theme}" "${_anl_flavor}" || return 1
    ln -sfn "$(path_nvim_palette "${_anl_theme}" "${_anl_flavor}")" "$(path_content_nvim_theme_link)"
}

# _th_bat_cmd
#   Print the command that runs bat: `bat`, or `batcat` when only that exists
#   (Debian/Ubuntu); print nothing when neither does. Same rule as DOTS_BAT in
#   content/home/.config/zsh/.zshenv.
_th_bat_cmd() {
    if command -v bat >/dev/null 2>&1; then
        printf 'bat'
    elif command -v batcat >/dev/null 2>&1; then
        printf 'batcat'
    fi
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
    if [ -z "${_twm_prompt}" ]; then
        _twm_prompt="$(dots_local_get DOTS_PROMPT 2>/dev/null || printf '')"
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
#   Full theme apply: validate → nvim link preflight → dotbot → nvim link →
#   starship fence → local state → bat cache → tmux reload → manifest.
#   The Herdr fence, the tmux reload, the Herdr reload and the Neovim link only
#   run for the components selected with ./dots components; the rest always runs.
#   Returns 0 on success, non-zero on any failure.
# ---------------------------------------------------------------------------
theme_apply() {
    _ta_theme="${1:?theme_apply: theme required}"
    _ta_flavor="${2:?theme_apply: flavor required}"

    # --- Step 1: Validate ---
    theme_validate "${_ta_theme}" "${_ta_flavor}" || return 1

    # --- Step 1b: Neovim link preflight ---
    # The nvim link step runs after dotbot; checking its failure modes here
    # means they surface while nothing has changed yet. Only when nvim is
    # selected (./dots components).
    if components_has nvim; then
        _th_check_nvim_link "${_ta_theme}" "${_ta_flavor}" || return 1
    fi

    # --- Step 2: Dotbot per-theme run ---
    dotbot_theme_apply "${_ta_theme}" "${_ta_flavor}" || return 1

    # --- Step 2b: Neovim palette link ---
    # nvim reads lua/dots-theme.lua (a repo-side, gitignored symlink) to pick
    # its colorscheme; no dotbot entry is needed because ~/.config/nvim/lua is
    # itself a link to that directory.
    # Skipped unless nvim is selected (./dots components).
    if components_has nvim; then
        _th_apply_nvim_link "${_ta_theme}" "${_ta_flavor}" || return 1
    fi

    # --- Step 3: starship fence (active palette selected in place) ---
    # Starship has no external-theme include, so the active palette is chosen by
    # a single `palette = "<theme>_<flavor>"` line inside the same dots:theme
    # fence; the per-theme palettes all live in the one starship.toml.
    _ta_starship_conf="$(_th_starship_conf_path)"
    if [ -f "${_ta_starship_conf}" ]; then
        _th_apply_fence "${_ta_starship_conf}" \
            "palette = \"${_ta_theme}_${_ta_flavor}\"" \
            '^[[]' || return 1
    fi

    # --- Step 3b: Herdr config fence ---
    # Herdr ships built-in theme names, so dots maps its richer flavor matrix
    # to the closest Herdr built-in and keeps auto_switch disabled.
    # Skipped unless a Herdr component is selected (./dots components).
    if components_has_any herdr-tui herdr-core herdr-app; then
        _th_apply_herdr_theme "${_ta_theme}" "${_ta_flavor}" || return 1
    fi

    # --- Step 3c: machine-local theme state ---
    # p10k reads its palette and tmux.conf its @themux_theme from DOTS_THEME,
    # so the choice lives in local.zsh instead of a repo fence. A reload
    # marker is dropped when p10k is active, since it cannot re-read the
    # palette in place (starship re-reads its config every prompt and needs
    # nothing; tmux is refreshed in Step 5).
    dots_local_set DOTS_THEME "${_ta_theme}_${_ta_flavor}" || return 1
    if [ "$(_th_read_manifest_field prompt 2>/dev/null || printf '')" = "p10k" ]; then
        dots_request_reload
    fi

    # --- Step 4: Bat cache rebuild ---
    _ta_bat="$(_th_bat_cmd)"
    if [ -n "${_ta_bat}" ]; then
        "${_ta_bat}" cache --build >/dev/null
    else
        log_warn "bat not installed; skipping bat cache rebuild"
    fi

    # --- Step 5: Tmux server reload ---
    # tmux.conf reads @themux_theme from DOTS_THEME at parse time, and the
    # server keeps the environment it was started with, so push the new value
    # into its global environment before re-sourcing the config.
    # Skipped unless tmux is selected (./dots components).
    if components_has tmux && tmux info >/dev/null 2>&1; then
        tmux set-environment -g DOTS_THEME "${_ta_theme}_${_ta_flavor}" 2>/dev/null \
            || log_warn "tmux set-environment failed; active sessions may keep the old theme"
        tmux source-file "$(path_home_tmux_config)" 2>/dev/null \
            || log_warn "tmux source-file failed; active sessions may need a manual reload"
    fi

    # --- Step 6: Herdr server reload (only when a Herdr component is selected) ---
    if components_has_any herdr-tui herdr-core herdr-app \
        && command -v herdr >/dev/null 2>&1 && herdr status server >/dev/null 2>&1; then
        herdr server reload-config >/dev/null 2>&1 \
            || log_warn "herdr reload-config failed; active clients may keep the old theme"
    fi

    # --- Step 7: Write manifest ---
    _th_write_manifest "${_ta_theme}" "${_ta_flavor}" || {
        log_error "Failed to write manifest"
        return 1
    }
}
