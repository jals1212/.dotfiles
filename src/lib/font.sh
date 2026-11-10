# shellcheck shell=sh
# lib/font.sh — terminal font selection (jetbrains-mono | iosevka)
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/paths.sh, lib/log.sh, lib/detect.sh, lib/theme.sh (local state),
# lib/components.sh (is herdr-app selected); jq or python3 for the Herdr app.
#
# The font choice is machine-local, like the prompt engine: it is recorded as
# DOTS_FONT in ~/.config/zsh/local.zsh and rendered into
# ~/.config/ghostty/font.conf, which the tracked Ghostty config loads with
# `config-file = ?font.conf`. The repo itself never changes when switching.
# When the herdr-app component is selected the font is also set in Herdr app's
# own settings.json (key "font"), which Herdr reloads live.

if ! command -v components_has >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/components.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/components.sh"
    fi
fi

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

# font_herdr_app_settings_path — print Herdr app's settings.json path.
font_herdr_app_settings_path() {
    printf '%s/herdr-app/settings.json\n' "${XDG_CONFIG_HOME:-$(path_home_file .config)}"
}

# _font_herdr_app_write <settings> <family> <tmp>
#   Write <tmp> = <settings> (or {}) with "font" set to <family>, every other
#   key kept. Uses jq, else python3. Fails when the existing file is not a
#   JSON object, or when neither tool exists (status 3).
_font_herdr_app_write() {
    if command -v jq >/dev/null 2>&1; then
        if [ -f "$1" ]; then
            jq -e 'type == "object"' "$1" >/dev/null 2>&1 || return 1
            jq --arg f "$2" '.font = $f' "$1" > "$3"
        else
            jq -n --arg f "$2" '{font: $f}' > "$3"
        fi
        return $?
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$1" "$2" "$3" <<'PY'
import json, os, sys
src, family, dst = sys.argv[1:4]
data = {}
if os.path.exists(src):
    with open(src, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        sys.exit(1)
data["font"] = family
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
        return $?
    fi
    return 3
}

# _font_herdr_app_apply <font>
#   When herdr-app is selected, set "font" in Herdr app's settings.json to the
#   font's family, atomically (temp file + mv), creating the file and its
#   directory when missing. Never fails: a missing jq/python3 or an existing
#   file that is not a JSON object only warns and leaves the file untouched.
#   Not selected: nothing is read or written.
_font_herdr_app_apply() {
    command -v components_has >/dev/null 2>&1 || return 0
    components_has herdr-app || return 0
    _fh_file="$(font_herdr_app_settings_path)"
    _fh_family="$(font_family "$1")" || return 0
    mkdir -p "$(dirname "${_fh_file}")" || {
        log_warn "Could not create $(dirname "${_fh_file}"); Herdr app font left unchanged"
        return 0
    }
    _fh_tmp="${_fh_file}.tmp.$$"
    # Keep the permissions of an existing file on the replacement.
    if [ -f "${_fh_file}" ]; then
        cp -p "${_fh_file}" "${_fh_tmp}" 2>/dev/null || : > "${_fh_tmp}"
    fi
    _fh_rc=0
    _font_herdr_app_write "${_fh_file}" "${_fh_family}" "${_fh_tmp}" || _fh_rc=$?
    if [ "${_fh_rc}" -eq 0 ] && mv "${_fh_tmp}" "${_fh_file}"; then
        return 0
    fi
    rm -f "${_fh_tmp}"
    if [ "${_fh_rc}" -eq 3 ]; then
        log_warn "Neither jq nor python3 found; Herdr app font in ${_fh_file} left unchanged"
    else
        log_warn "${_fh_file} is not a valid JSON object (or could not be written); Herdr app font left unchanged"
    fi
    return 0
}

# font_apply <font>
#   Validate → font.conf → local.zsh → Herdr app settings (when selected) →
#   cask (macOS).
font_apply() {
    _fa_font="${1:?font_apply: font required}"
    font_validate "${_fa_font}" || return 1

    _fa_conf="$(font_conf_path)"
    mkdir -p "$(dirname "${_fa_conf}")" || return 1
    printf 'font-family = "%s"\n' "$(font_family "${_fa_font}")" > "${_fa_conf}.tmp" &&
        mv "${_fa_conf}.tmp" "${_fa_conf}" || return 1

    dots_local_set DOTS_FONT "${_fa_font}" || return 1
    _font_herdr_app_apply "${_fa_font}"
    _font_ensure_cask "${_fa_font}"
}
