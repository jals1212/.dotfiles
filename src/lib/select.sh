#!/bin/sh
# lib/select.sh — interactive theme/flavor/prompt pickers (lib/tui.sh)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/tui.sh (tui_choose, tui_card), jq.
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
# select_theme <repo_root> [current_theme]
#   Presents a tui_choose picker over themes derived from the shared theme
#   index (content/themes/index.yaml). Pre-focuses current_theme when provided.
# ---------------------------------------------------------------------------
select_theme() {
    _st_root="${1}"
    _st_current="${2:-}"

    _st_themes="$(_themes_from_index "${_st_root}")" || {
        log_error "Theme index missing or unreadable: ${_st_root}/content/themes/index.yaml"
        exit 1
    }
    if [ -z "${_st_themes}" ]; then
        log_error "No themes found in ${_st_root}/content/themes/index.yaml"
        exit 1
    fi
    _TUI_PICK_ACCENT="$(_header_color_code "${_st_current:-kanagawa}")"
    # shellcheck disable=SC2086
    _st_chosen="$(tui_choose "Select theme:" "${_st_current}" ${_st_themes})" || exit 130
    printf '%s' "${_st_chosen}"
}

# ---------------------------------------------------------------------------
# select_flavor <repo_root> <theme> [current_flavor]
#   Presents a tui_choose picker over flavors for the given theme, derived
#   from the shared theme index (content/themes/index.yaml).
# ---------------------------------------------------------------------------
select_flavor() {
    _sf_root="${1}"
    _sf_theme="${2:?select_flavor: theme required}"
    _sf_current="${3:-}"

    _sf_flavors="$(_flavors_from_index "${_sf_root}" "${_sf_theme}")" || {
        log_error "Theme index missing or unreadable: ${_sf_root}/content/themes/index.yaml"
        exit 1
    }
    if [ -z "${_sf_flavors}" ]; then
        log_error "No flavors found for theme ${_sf_theme} in the theme index"
        exit 1
    fi
    _TUI_PICK_ACCENT="$(_header_color_code "${_sf_theme}")"
    # shellcheck disable=SC2086
    _sf_chosen="$(tui_choose "Select flavor for ${_sf_theme}:" "${_sf_current}" ${_sf_flavors})" || exit 130
    printf '%s' "${_sf_chosen}"
}

# ---------------------------------------------------------------------------
# select_prompt [current_engine]
#   Presents a tui_choose picker over the supported prompt engines.
#   Pre-focuses current_engine when provided.
# ---------------------------------------------------------------------------
select_prompt() {
    _sp_current="${1:-}"

    _sp_chosen="$(tui_choose "Select prompt engine:" "${_sp_current}" starship p10k)" || exit 130
    printf '%s' "${_sp_chosen}"
}

# ---------------------------------------------------------------------------
# confirm_apply <theme> <flavor>
#   Presents a summary card listing theme + flavor and prompts
#   the operator to confirm. Returns 0 on yes, 1 on no/cancel.
# ---------------------------------------------------------------------------
confirm_apply() {
    _ca_theme="${1:?confirm_apply: theme required}"
    _ca_flavor="${2:?confirm_apply: flavor required}"

    tui_card "$(_header_color_code "${_ca_theme}")" "Selection summary" \
        "Theme:  ${_ca_theme}" "Flavor: ${_ca_flavor}"
    tui_confirm "Apply selection?" n
}
