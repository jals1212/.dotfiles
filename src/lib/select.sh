#!/bin/sh
# lib/select.sh — interactive theme/flavor picker helpers (gum-backed)
# POSIX sh. Source this file; do not execute directly.
# Requires: gum (brew install gum), jq.
#
# The tools picker was removed in migrate-to-dotbot: managed packages live in
# Brewfile and home/.config/mise/config.toml, not in a per-run picker.

# shellcheck source=src/lib/log.sh
# shellcheck source=src/lib/detect.sh
# shellcheck source=src/lib/header.sh

if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

if ! command -v _header_color_code >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib header.sh)" ]; then
        # shellcheck disable=SC1091
        . "$(path_src_lib header.sh)"
    fi
fi

# ---------------------------------------------------------------------------
# Hardcoded defaults consumed when no manifest exists (fresh clone).
# ---------------------------------------------------------------------------
_SELECT_DEFAULT_THEME="kanagawa"
_SELECT_DEFAULT_FLAVOR="dragon"

# ---------------------------------------------------------------------------
# _themes_from_index <repo_root>
#   Emits the supported theme names (one per line) parsed from the shared
#   theme index content/themes/index.yaml. Theme keys are indented two
#   spaces under the top-level `themes:` map.
# ---------------------------------------------------------------------------
_themes_from_index() {
    _tfi_root="${1:?_themes_from_index: repo root required}"
    _tfi_index="${_tfi_root}/content/themes/index.yaml"
    [ -f "${_tfi_index}" ] || return 1
    sed -n 's/^  \([A-Za-z][A-Za-z0-9_-]*\):$/\1/p' "${_tfi_index}" | sort
}

# ---------------------------------------------------------------------------
# _flavors_from_index <repo_root> <theme>
#   Emits the flavors (one per line) for <theme> parsed from the inline
#   `flavors: [a, b, c]` list in content/themes/index.yaml.
# ---------------------------------------------------------------------------
_flavors_from_index() {
    _ffi_root="${1:?_flavors_from_index: repo root required}"
    _ffi_theme="${2:?_flavors_from_index: theme required}"
    _ffi_index="${_ffi_root}/content/themes/index.yaml"
    [ -f "${_ffi_index}" ] || return 1
    awk -v t="${_ffi_theme}" '
        $0 ~ "^  " t ":$" { f = 1; next }
        f && /^  [A-Za-z][A-Za-z0-9_-]*:$/ { f = 0 }
        f && /flavors:/ {
            line = $0
            sub(/.*\[/, "", line); sub(/\].*/, "", line)
            gsub(/[ ,]+/, "\n", line)
            print line
            exit
        }
    ' "${_ffi_index}" | sed '/^$/d' | sort
}

# ---------------------------------------------------------------------------
# _styled_header <text> [theme]
#   Returns a gum-styled picker header using the active/theme accent colour.
# ---------------------------------------------------------------------------
_styled_header() {
    _sh_text="${1:?_styled_header: text required}"
    _sh_theme="${2:-kanagawa}"
    _check_gum
    gum style --foreground "$(_header_color_code "${_sh_theme}")" "${_sh_text}"
}

# ---------------------------------------------------------------------------
# read_current_selection <repo_root>
#   Returns the current "selection state" as a single space-separated line:
#       <theme> <flavor>
#   Source of truth (in order):
#     1. ${repo_root}/manifest.json (slim schema) when present and valid.
#     2. Hardcoded defaults from this file.
# ---------------------------------------------------------------------------
read_current_selection() {
    _rcs_repo="${1:?read_current_selection: repo_root required}"
    _rcs_manifest="$(path_manifest "${_rcs_repo}")"

    if [ -f "${_rcs_manifest}" ] && jq empty "${_rcs_manifest}" 2>/dev/null; then
        _rcs_theme="$(jq -r '.theme // empty' "${_rcs_manifest}")"
        _rcs_flavor="$(jq -r '.flavor // empty' "${_rcs_manifest}")"
        if [ -n "${_rcs_theme}" ] && [ -n "${_rcs_flavor}" ]; then
            printf '%s %s\n' "${_rcs_theme}" "${_rcs_flavor}"
            return 0
        fi
    fi

    printf '%s %s\n' "${_SELECT_DEFAULT_THEME}" "${_SELECT_DEFAULT_FLAVOR}"
}

# ---------------------------------------------------------------------------
# _check_gum
#   Verifies gum is available; exits 1 with error if not.
# ---------------------------------------------------------------------------
_check_gum() {
    if ! command -v gum >/dev/null 2>&1; then
        log_error "gum is required (install with: brew install gum)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# validate_theme <theme>
#   Confirms <theme> is one of the supported themes.
# ---------------------------------------------------------------------------
validate_theme() {
    _vt_theme="${1}"
    case "${_vt_theme}" in
        kanagawa|catppuccin) return 0 ;;
        *)
            log_error "Unknown theme: ${_vt_theme}. Supported: kanagawa, catppuccin"
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# validate_flavor <theme> <flavor>
#   Confirms <flavor> is valid for the given theme.
# ---------------------------------------------------------------------------
validate_flavor() {
    _vf_theme="${1}"
    _vf_flavor="${2}"
    case "${_vf_theme}:${_vf_flavor}" in
        kanagawa:dragon|kanagawa:lotus|kanagawa:wave) return 0 ;;
        catppuccin:frappe|catppuccin:latte|catppuccin:macchiato|catppuccin:mocha) return 0 ;;
        *)
            log_error "Invalid flavor ${_vf_flavor} for theme ${_vf_theme}."
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# select_theme <repo_root> [current_theme]
#   Presents a gum choose picker over themes derived from the shared theme
#   index (content/themes/index.yaml). Pre-focuses current_theme when provided.
# ---------------------------------------------------------------------------
select_theme() {
    _st_root="${1}"
    _st_current="${2:-}"

    _check_gum

    _st_themes="$(_themes_from_index "${_st_root}")" || {
        log_error "Theme index missing or unreadable: ${_st_root}/content/themes/index.yaml"
        exit 1
    }
    if [ -z "${_st_themes}" ]; then
        log_error "No themes found in ${_st_root}/content/themes/index.yaml"
        exit 1
    fi
    _st_header_text="Select theme:"
    _st_header="$(_styled_header "${_st_header_text}" "${_st_current:-kanagawa}")"

    _st_selected_arg=""
    if [ -n "${_st_current}" ]; then
        _st_selected_arg="--selected=${_st_current}"
    fi

    # shellcheck disable=SC2086
    _st_chosen="$(printf '%s\n' ${_st_themes} | gum choose --header "${_st_header}" ${_st_selected_arg})"

    [ -z "${_st_chosen}" ] && exit 130
    printf '%s' "${_st_chosen}"
}

# ---------------------------------------------------------------------------
# select_flavor <repo_root> <theme> [current_flavor]
#   Presents a gum choose picker over flavors for the given theme, derived
#   from the shared theme index (content/themes/index.yaml).
# ---------------------------------------------------------------------------
select_flavor() {
    _sf_root="${1}"
    _sf_theme="${2:?select_flavor: theme required}"
    _sf_current="${3:-}"

    _check_gum

    _sf_flavors="$(_flavors_from_index "${_sf_root}" "${_sf_theme}")" || {
        log_error "Theme index missing or unreadable: ${_sf_root}/content/themes/index.yaml"
        exit 1
    }
    if [ -z "${_sf_flavors}" ]; then
        log_error "No flavors found for theme ${_sf_theme} in the theme index"
        exit 1
    fi
    _sf_header_text="Select flavor for ${_sf_theme}:"
    _sf_header="$(_styled_header "${_sf_header_text}" "${_sf_theme}")"

    _sf_selected_arg=""
    if [ -n "${_sf_current}" ]; then
        _sf_selected_arg="--selected=${_sf_current}"
    fi

    # shellcheck disable=SC2086
    _sf_chosen="$(printf '%s\n' ${_sf_flavors} | gum choose --header "${_sf_header}" ${_sf_selected_arg})"

    [ -z "${_sf_chosen}" ] && exit 130
    printf '%s' "${_sf_chosen}"
}

# ---------------------------------------------------------------------------
# confirm_apply <theme> <flavor>
#   Presents a gum-styled summary card listing theme + flavor and prompts
#   the operator to confirm. Returns 0 on yes, 1 on no/cancel.
# ---------------------------------------------------------------------------
confirm_apply() {
    _ca_theme="${1:?confirm_apply: theme required}"
    _ca_flavor="${2:?confirm_apply: flavor required}"

    _check_gum
    gum style \
        --border rounded \
        --border-foreground "$(_header_color_code "${_ca_theme}")" \
        --padding "1 2" \
        --bold \
        "Selection summary
Theme: ${_ca_theme}
Flavor: ${_ca_flavor}"
    gum confirm "Apply selection?"
}
