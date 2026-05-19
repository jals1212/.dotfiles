#!/bin/sh
# lib/select.sh — interactive selection helpers (gum-backed)
# POSIX sh. Source this file; do not execute directly.
# Requires: gum (brew install gum), jq.

# shellcheck source=lib/log.sh
# shellcheck source=lib/detect.sh

# ---------------------------------------------------------------------------
# Internal constants
# ---------------------------------------------------------------------------

# Canonical list of managed tools (order = presentation + stable JSON order).
# Order matches the spec-mandated default: zsh tmux nvim ghostty oh-my-posh atuin zoxide.
_SELECT_TOOLS="zsh tmux nvim ghostty oh-my-posh atuin zoxide"

# Hardcoded defaults consumed when no manifest exists (fresh clone).
_SELECT_DEFAULT_THEME="kanagawa"
_SELECT_DEFAULT_FLAVOR="dragon"
_SELECT_DEFAULT_ACCENT="mauve"
_SELECT_DEFAULT_TOOLS_CSV="zsh,tmux,nvim,ghostty,oh-my-posh,atuin,zoxide"

# ---------------------------------------------------------------------------
# read_current_selection <repo_root>
#   Returns the current "selection state" as a single space-separated line:
#       <theme> <flavor> <accent> <tools_csv>
#   Source of truth (in order):
#     1. ${repo_root}/manifest.json (post-apply state) when present and valid.
#     2. Hardcoded defaults from this file.
#   Note: the transitory .dots-selection.json is intentionally NOT consulted;
#   it represents intent-in-progress, not state.
# ---------------------------------------------------------------------------
read_current_selection() {
    _rcs_repo="${1:?read_current_selection: repo_root required}"
    _rcs_manifest="${_rcs_repo}/manifest.json"

    if [ -f "${_rcs_manifest}" ] && jq empty "${_rcs_manifest}" 2>/dev/null; then
        _rcs_theme="$(jq -r '.theme // empty' "${_rcs_manifest}")"
        _rcs_flavor="$(jq -r '.flavor // empty' "${_rcs_manifest}")"
        _rcs_accent="$(jq -r '.accent // empty' "${_rcs_manifest}")"
        _rcs_tools="$(jq -r '.tools | join(",") // empty' "${_rcs_manifest}")"
        if [ -n "${_rcs_theme}" ] && [ -n "${_rcs_flavor}" ] && [ -n "${_rcs_tools}" ]; then
            printf '%s %s %s %s\n' "${_rcs_theme}" "${_rcs_flavor}" "${_rcs_accent:-${_SELECT_DEFAULT_ACCENT}}" "${_rcs_tools}"
            return 0
        fi
    fi

    printf '%s %s %s %s\n' \
        "${_SELECT_DEFAULT_THEME}" \
        "${_SELECT_DEFAULT_FLAVOR}" \
        "${_SELECT_DEFAULT_ACCENT}" \
        "${_SELECT_DEFAULT_TOOLS_CSV}"
}

# ---------------------------------------------------------------------------
# _check_gum
#   Verifies gum is available; exits 1 with error if not.
# ---------------------------------------------------------------------------
_check_gum() {
    if ! command -v gum >/dev/null 2>&1; then
        log_error "gum is required but not found on PATH. Run: brew install gum"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# _check_jq
#   Verifies jq is available; exits 1 with error if not.
# ---------------------------------------------------------------------------
_check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required but not found on PATH. Run: brew install jq"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# validate_theme <repo_root> <theme>
#   Verifies that assets/themes/oh-my-posh/<theme>/ exists.
#   Exits 1 with log_error listing valid themes on failure.
# ---------------------------------------------------------------------------
validate_theme() {
    _vt_root="${1}"
    _vt_theme="${2}"
    _vt_themes_dir="${_vt_root}/assets/themes/oh-my-posh"

    if [ ! -d "${_vt_themes_dir}/${_vt_theme}" ]; then
        _vt_valid="$(find "${_vt_themes_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')"
        log_error "Unknown theme '${_vt_theme}'. Valid themes: ${_vt_valid}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# validate_flavor <repo_root> <theme> <flavor>
#   Verifies that assets/themes/oh-my-posh/<theme>/<flavor>.json exists.
#   Exits 1 with log_error listing valid flavors on failure.
# ---------------------------------------------------------------------------
validate_flavor() {
    _vf_root="${1}"
    _vf_theme="${2}"
    _vf_flavor="${3}"
    _vf_theme_dir="${_vf_root}/assets/themes/oh-my-posh/${_vf_theme}"

    if [ ! -f "${_vf_theme_dir}/${_vf_flavor}.json" ]; then
        _vf_valid="$(find "${_vf_theme_dir}" -maxdepth 1 -name '*.json' -exec basename {} .json \; 2>/dev/null | sort | tr '\n' ' ')"
        log_error "Unknown flavor '${_vf_flavor}' for theme '${_vf_theme}'. Valid flavors: ${_vf_valid}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# validate_accent <repo_root> <theme> <accent>
#   When theme=catppuccin: verifies that assets/themes/atuin/catppuccin/<accent>.toml exists.
#   For other themes: accent is unconstrained (defaults to mauve); always passes.
#   Exits 1 with log_error on failure.
# ---------------------------------------------------------------------------
validate_accent() {
    _va_root="${1}"
    _va_theme="${2}"
    _va_accent="${3}"

    if [ "${_va_theme}" = "catppuccin" ]; then
        _va_accent_dir="${_va_root}/assets/themes/atuin/catppuccin"
        if [ ! -f "${_va_accent_dir}/${_va_accent}.toml" ]; then
            _va_valid="$(find "${_va_accent_dir}" -maxdepth 1 -name '*.toml' -exec basename {} .toml \; 2>/dev/null | sort | tr '\n' ' ')"
            log_error "Unknown accent '${_va_accent}' for catppuccin. Valid accents: ${_va_valid}"
            exit 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# validate_tools <tools_csv>
#   Validates each tool in the comma-separated list against the canonical seven.
#   Exits 1 with log_error on any unknown tool.
# ---------------------------------------------------------------------------
validate_tools() {
    _vtl_csv="${1}"
    # Convert CSV to newline-separated for iteration
    _vtl_list="$(printf '%s' "${_vtl_csv}" | tr ',' '\n')"

    _vtl_unknown=""
    # Iterate over CSV by temporarily splitting on commas.
    # We replace commas with newlines so the POSIX for-loop can iterate.
    _vtl_oldifs="${IFS}"
    IFS=","
    for _vtl_tool in ${_vtl_csv}; do
        IFS="${_vtl_oldifs}"
        # Trim leading/trailing whitespace
        _vtl_tool="$(printf '%s' "${_vtl_tool}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "${_vtl_tool}" ] && IFS="," && continue

        _vtl_found=0
        # _SELECT_TOOLS is space-separated; default IFS handles split
        for _vtl_known in ${_SELECT_TOOLS}; do
            if [ "${_vtl_tool}" = "${_vtl_known}" ]; then
                _vtl_found=1
                break
            fi
        done

        if [ "${_vtl_found}" -eq 0 ]; then
            _vtl_unknown="${_vtl_unknown} ${_vtl_tool}"
        fi
        IFS=","
    done
    IFS="${_vtl_oldifs}"

    if [ -n "${_vtl_unknown}" ]; then
        log_error "Unknown tool(s):${_vtl_unknown}. Valid tools: ${_SELECT_TOOLS}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# select_theme <repo_root> [current_theme]
#   Presents a gum choose picker over available themes.
#   If current_theme is provided and matches an available theme, gum pre-focuses it.
#   Prints chosen theme to stdout.
# ---------------------------------------------------------------------------
select_theme() {
    _st_root="${1}"
    _st_current="${2:-}"
    _st_themes_dir="${_st_root}/assets/themes/oh-my-posh"

    _check_gum

    # Collect available themes (directory basenames, sorted)
    _st_themes="$(find "${_st_themes_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"

    if [ -z "${_st_themes}" ]; then
        log_error "No themes found in ${_st_themes_dir}"
        exit 1
    fi

    _st_selected_arg=""
    if [ -n "${_st_current}" ]; then
        _st_selected_arg="--selected=${_st_current}"
    fi

    # shellcheck disable=SC2086
    _st_chosen="$(printf '%s\n' ${_st_themes} | gum choose --header "Select a theme:" ${_st_selected_arg})"
    if [ -z "${_st_chosen}" ]; then
        log_error "No theme selected. Exiting."
        exit 1
    fi

    printf '%s' "${_st_chosen}"
}

# ---------------------------------------------------------------------------
# select_flavor <repo_root> <theme> [current_flavor]
#   Presents a gum choose picker over available flavors for the given theme.
#   If current_flavor is provided and matches, gum pre-focuses it.
#   Prints chosen flavor to stdout.
# ---------------------------------------------------------------------------
select_flavor() {
    _sf_root="${1}"
    _sf_theme="${2}"
    _sf_current="${3:-}"
    _sf_theme_dir="${_sf_root}/assets/themes/oh-my-posh/${_sf_theme}"

    _check_gum

    # Collect flavor names (JSON basenames without .json extension, sorted)
    _sf_flavors="$(find "${_sf_theme_dir}" -maxdepth 1 -name '*.json' -exec basename {} .json \; 2>/dev/null | sort)"

    if [ -z "${_sf_flavors}" ]; then
        log_error "No flavors found for theme '${_sf_theme}' in ${_sf_theme_dir}"
        exit 1
    fi

    _sf_selected_arg=""
    if [ -n "${_sf_current}" ]; then
        _sf_selected_arg="--selected=${_sf_current}"
    fi

    # shellcheck disable=SC2086
    _sf_chosen="$(printf '%s\n' ${_sf_flavors} | gum choose --header "Select a flavor for ${_sf_theme}:" ${_sf_selected_arg})"
    if [ -z "${_sf_chosen}" ]; then
        log_error "No flavor selected. Exiting."
        exit 1
    fi

    printf '%s' "${_sf_chosen}"
}

# ---------------------------------------------------------------------------
# select_accent <repo_root> <theme>
#   When theme=catppuccin: presents gum choose over atuin accent toml files.
#   For other themes: emits 'mauve' silently and returns 0 without prompting.
#   Prints chosen accent to stdout.
# ---------------------------------------------------------------------------
select_accent() {
    _sa_root="${1}"
    _sa_theme="${2}"
    _sa_current="${3:-}"

    if [ "${_sa_theme}" != "catppuccin" ]; then
        printf 'mauve'
        return 0
    fi

    _check_gum

    _sa_accent_dir="${_sa_root}/assets/themes/atuin/catppuccin"

    # Collect accent names (toml basenames without .toml extension, sorted)
    _sa_accents="$(find "${_sa_accent_dir}" -maxdepth 1 -name '*.toml' -exec basename {} .toml \; 2>/dev/null | sort)"

    if [ -z "${_sa_accents}" ]; then
        log_error "No accent files found in ${_sa_accent_dir}"
        exit 1
    fi

    _sa_selected_arg=""
    if [ -n "${_sa_current}" ]; then
        _sa_selected_arg="--selected=${_sa_current}"
    fi

    # shellcheck disable=SC2086
    _sa_chosen="$(printf '%s\n' ${_sa_accents} | gum choose --header "Select an accent color:" ${_sa_selected_arg})"
    if [ -z "${_sa_chosen}" ]; then
        log_error "No accent selected. Exiting."
        exit 1
    fi

    printf '%s' "${_sa_chosen}"
}

# ---------------------------------------------------------------------------
# select_tools <repo_root>
#   Presents a gum choose --no-limit picker over the seven managed tools.
#   All seven are pre-selected by default.
#   Prints chosen tools as newline-separated list to stdout.
#   Re-prompts if user selects no tools (at least one required).
# ---------------------------------------------------------------------------
select_tools() {
    _stl_root="${1}"
    _stl_current_csv="${2:-${_SELECT_DEFAULT_TOOLS_CSV}}"
    # repo_root unused directly here but kept for signature consistency
    : "${_stl_root}"

    _check_gum

    while true; do
        # shellcheck disable=SC2086
        _stl_chosen="$(printf '%s\n' ${_SELECT_TOOLS} | \
            gum choose --no-limit \
                --header "Select tools to install (SPACE to toggle, ENTER to confirm):" \
                --selected="${_stl_current_csv}")"

        if [ -z "${_stl_chosen}" ]; then
            log_warn "At least one tool must be selected. Please try again."
        else
            break
        fi
    done

    printf '%s' "${_stl_chosen}"
}

# ---------------------------------------------------------------------------
# confirm_apply
#   Presents a gum confirm prompt before writing the selection.
#   Returns 0 on yes, 1 on no/cancel.
# ---------------------------------------------------------------------------
confirm_apply() {
    _check_gum
    gum confirm "Apply selection?"
}

# ---------------------------------------------------------------------------
# write_selection <path> <theme> <flavor> <accent> <tools_csv>
#   Validates all inputs, then atomically writes .dots-selection.json.
#   Stable key order: theme, flavor, accent, tools.
#   Exits 1 on validation failure or write failure.
#
#   <tools_csv>  — comma-separated tool names (e.g. "zsh,tmux,nvim")
#   <path>       — destination file (e.g. "${REPO_ROOT}/.dots-selection.json")
# ---------------------------------------------------------------------------
write_selection() {
    _ws_path="${1}"
    _ws_theme="${2}"
    _ws_flavor="${3}"
    _ws_accent="${4}"
    _ws_tools_csv="${5}"

    _check_jq

    # Derive repo_root from the path's dirname for validation
    _ws_root="$(dirname "${_ws_path}")"

    # Validate all inputs before touching the filesystem
    validate_theme  "${_ws_root}" "${_ws_theme}"
    validate_flavor "${_ws_root}" "${_ws_theme}" "${_ws_flavor}"
    validate_accent "${_ws_root}" "${_ws_theme}" "${_ws_accent}"
    validate_tools  "${_ws_tools_csv}"

    # Convert CSV → JSON array.  Each element is trimmed of whitespace.
    # We build a quoted jq array string by converting commas to '","'
    _ws_tools_json="$(printf '%s' "${_ws_tools_csv}" | \
        jq -R 'split(",") | map(ltrimstr(" ") | rtrimstr(" ")) | map(select(length > 0))')"

    # Atomic write: tmp → mv
    _ws_tmp="${_ws_path}.tmp"
    jq -n \
        --arg   theme  "${_ws_theme}" \
        --arg   flavor "${_ws_flavor}" \
        --arg   accent "${_ws_accent}" \
        --argjson tools "${_ws_tools_json}" \
        '{theme: $theme, flavor: $flavor, accent: $accent, tools: $tools}' \
        > "${_ws_tmp}" || { log_error "jq failed to produce selection JSON"; exit 1; }

    mv "${_ws_tmp}" "${_ws_path}" || { log_error "Failed to write ${_ws_path}"; exit 1; }

    log_info "Selection written to ${_ws_path}"
}
