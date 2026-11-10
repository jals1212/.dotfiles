# shellcheck shell=sh
# lib/font.sh — terminal font selection (jetbrains-mono | iosevka)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/detect.sh, lib/theme.sh (local state).
#
# The font choice is machine-local, like the prompt engine: it is recorded as
# DOTS_FONT in ~/.config/zsh/local.zsh and rendered into
# ~/.config/ghostty/font.conf, which the tracked Ghostty config loads with
# `config-file = ?font.conf`. The repo itself never changes when switching.

FONT_CHOICES="jetbrains-mono iosevka"
FONT_DEFAULT="jetbrains-mono"

# font_family <font> — print the Ghostty font-family name for <font>.
font_family() {
    case "${1:-}" in
        jetbrains-mono) printf 'JetBrainsMono Nerd Font\n' ;;
        iosevka)        printf 'IosevkaTerm NF\n' ;;
        *) return 1 ;;
    esac
}

# font_cask <font> — print the Homebrew cask that provides <font>.
font_cask() {
    case "${1:-}" in
        jetbrains-mono) printf 'font-jetbrains-mono-nerd-font\n' ;;
        iosevka)        printf 'font-iosevka-term-nerd-font\n' ;;
        *) return 1 ;;
    esac
}

# font_validate <font> — succeed when <font> is a supported choice.
font_validate() {
    _fv_font="${1:?font_validate: font required}"
    for _fv_known in ${FONT_CHOICES}; do
        [ "${_fv_font}" = "${_fv_known}" ] && return 0
    done
    log_error "Unknown font '${_fv_font}'. Supported: ${FONT_CHOICES}"
    return 1
}

# font_recorded — print the recorded font, or nothing when none was chosen.
font_recorded() {
    dots_local_get DOTS_FONT 2>/dev/null || printf ''
}

# font_current — print the active font: the recorded choice or the default.
font_current() {
    _fc_font="$(font_recorded)"
    printf '%s\n' "${_fc_font:-${FONT_DEFAULT}}"
}

# font_conf_path — print ~/.config/ghostty/font.conf.
font_conf_path() {
    path_home_file ".config/ghostty/font.conf"
}

# _font_ensure_cask <font>
#   On macOS with brew available, install the font's Nerd Font cask when it
#   is missing. A failed install only warns: the choice is still recorded.
_font_ensure_cask() {
    [ "$(detect_os)" = "macos" ] || return 0
    command -v brew >/dev/null 2>&1 || {
        log_warn "brew not found; install the $(font_cask "$1") cask manually"
        return 0
    }
    _fec_cask="$(font_cask "$1")"
    brew list --cask "${_fec_cask}" >/dev/null 2>&1 && return 0
    log_step "Installing ${_fec_cask}..."
    brew install --cask "${_fec_cask}" ||
        log_warn "brew install --cask ${_fec_cask} failed; Ghostty falls back to its default font"
    return 0
}

# font_apply <font>
#   Validate → font.conf → local.zsh → cask (macOS).
font_apply() {
    _fa_font="${1:?font_apply: font required}"
    font_validate "${_fa_font}" || return 1

    _fa_conf="$(font_conf_path)"
    mkdir -p "$(dirname "${_fa_conf}")" || return 1
    printf 'font-family = "%s"\n' "$(font_family "${_fa_font}")" > "${_fa_conf}.tmp" &&
        mv "${_fa_conf}.tmp" "${_fa_conf}" || return 1

    dots_local_set DOTS_FONT "${_fa_font}" || return 1
    _font_ensure_cask "${_fa_font}"
}
