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

if ! command -v _header_color_code >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/header.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/header.sh"
    fi
fi

# ---------------------------------------------------------------------------
# Hardcoded defaults consumed when no manifest exists (fresh clone).
# ---------------------------------------------------------------------------
_SELECT_DEFAULT_THEME="kanagawa"
_SELECT_DEFAULT_FLAVOR="dragon"

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
    _rcs_manifest="${_rcs_repo}/manifest.json"

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
#   Presents a gum choose picker over available themes (derived from
#   content/assets/palettes/oh-my-posh/). Pre-focuses current_theme when provided.
# ---------------------------------------------------------------------------
select_theme() {
    _st_root="${1}"
    _st_current="${2:-}"
    _st_themes_dir="${_st_root}/content/assets/palettes/oh-my-posh"

    if [ ! -d "${_st_themes_dir}" ]; then
        log_error "Themes directory missing: ${_st_themes_dir}"
        exit 1
    fi

    _check_gum

    _st_themes="$(find "${_st_themes_dir}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
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
#   Presents a gum choose picker over flavors for the given theme (derived
#   from content/assets/palettes/oh-my-posh/<theme>/*.json).
# ---------------------------------------------------------------------------
select_flavor() {
    _sf_root="${1}"
    _sf_theme="${2:?select_flavor: theme required}"
    _sf_current="${3:-}"
    _sf_dir="${_sf_root}/content/assets/palettes/oh-my-posh/${_sf_theme}"

    if [ ! -d "${_sf_dir}" ]; then
        log_error "Theme directory missing: ${_sf_dir}"
        exit 1
    fi

    _check_gum

    _sf_flavors="$(find "${_sf_dir}" -mindepth 1 -maxdepth 1 -type f -name '*.json' -exec basename {} .json \; | sort)"
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
