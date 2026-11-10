#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/herdr_app_font.bats
# S10: when herdr-app is selected, `./dots font` (font_apply, shared with
# `./dots update`) sets the key "font" of
# ${XDG_CONFIG_HOME:-~/.config}/herdr-app/settings.json to the chosen font's
# family and keeps every other key. Not selected: the file is not touched.
# Invalid JSON or no jq/python3: warn, leave the file, font_apply still works.
#
# Safety: sandbox HOME and XDG_CONFIG_HOME; uname is a stub on PATH (no brew);
# nothing reaches the host's ~/.config/herdr-app (the Herdr app reloads it live).

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    unset XDG_CONFIG_HOME
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    FONT_CMD="${REPO_ROOT_REAL}/src/commands/font.sh"
    SETTINGS="${HOME}/.config/herdr-app/settings.json"
    JQ="$(command -v jq)"
    printf '#!/bin/sh\nprintf "Linux\\n"\n' > "${SANDBOX}/bin/uname"
    chmod +x "${SANDBOX}/bin/uname"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

_select() {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-%s}"\n' "$*" > "${LOCAL_ZSH}"
}

_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1 in: ${output}"; return 1; }

# _norm <file> — the JSON of <file> in canonical form (sorted keys, compact).
_norm() { "${JQ}" -S -c . "$1"; }

# _tools_path [python3] — PATH of symlinks to every system tool except jq and
# python*, plus the host python3 when asked, so the font code sees exactly the
# JSON tools the test wants it to.
_tools_path() {
    mkdir -p "${SANDBOX}/tools"
    for d in /usr/bin /bin /usr/sbin /sbin; do
        for f in "${d}"/*; do
            n="${f##*/}"
            case "${n}" in jq | python*) continue ;; esac
            [ -e "${SANDBOX}/tools/${n}" ] || ln -s "${f}" "${SANDBOX}/tools/${n}"
        done
    done
    [ "${1:-}" = python3 ] && ln -sf "$(command -v python3)" "${SANDBOX}/tools/python3"
    cp "${SANDBOX}/bin/uname" "${SANDBOX}/tools/uname.stub" && mv -f "${SANDBOX}/tools/uname.stub" "${SANDBOX}/tools/uname"
    printf '%s' "${SANDBOX}/tools"
}

@test "selected: sets font and keeps every other key" {
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{"font_size": 14, "ui_font": "Inter", "theme": {"name": "x", "n": [1, 2]}, "font": "Old"}\n' > "${SETTINGS}"

    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SETTINGS}")" = '{"font":"IosevkaTerm NF","font_size":14,"theme":{"n":[1,2],"name":"x"},"ui_font":"Inter"}' ]
    # No temp file left behind.
    [ "$(ls "$(dirname "${SETTINGS}")")" = "settings.json" ]
}

@test "selected: a missing file and directory are created with just the font" {
    _select herdr-core herdr-app
    [ ! -e "${HOME}/.config/herdr-app" ]

    run sh "${FONT_CMD}" jetbrains-mono
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SETTINGS}")" = '{"font":"JetBrainsMono Nerd Font"}' ]
}

@test "selected: switching the font twice updates the same key" {
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{"font_size": 13}\n' > "${SETTINGS}"

    sh "${FONT_CMD}" iosevka
    [ "$(_norm "${SETTINGS}")" = '{"font":"IosevkaTerm NF","font_size":13}' ]
    run sh "${FONT_CMD}" jetbrains-mono
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SETTINGS}")" = '{"font":"JetBrainsMono Nerd Font","font_size":13}' ]
}

@test "selected: XDG_CONFIG_HOME decides where settings.json lives" {
    _select herdr-app
    export XDG_CONFIG_HOME="${SANDBOX}/xdg"
    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SANDBOX}/xdg/herdr-app/settings.json")" = '{"font":"IosevkaTerm NF"}' ]
    [ ! -e "${SETTINGS}" ]
}

@test "not selected: an existing settings.json is byte-identical" {
    _select tmux ghostty
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{ "font" : "Mine",\n  "font_size":14 }\n' > "${SETTINGS}"
    cp "${SETTINGS}" "${SANDBOX}/before"

    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    cmp -s "${SETTINGS}" "${SANDBOX}/before"
}

@test "not selected (nothing recorded): no settings.json and no directory" {
    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.config/herdr-app" ]
}

@test "invalid JSON: warns, leaves the file, still applies the other steps, exit 0" {
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{"font_size": 14,,}\n' > "${SETTINGS}"
    cp "${SETTINGS}" "${SANDBOX}/before"

    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    _has "[WARN]"
    _has "settings.json"
    cmp -s "${SETTINGS}" "${SANDBOX}/before"
    [ "$(cat "${HOME}/.config/ghostty/font.conf")" = 'font-family = "IosevkaTerm NF"' ]
    grep -Fqx 'export DOTS_FONT="${DOTS_FONT:-iosevka}"' "${LOCAL_ZSH}"
    [ "$(ls "$(dirname "${SETTINGS}")")" = "settings.json" ]
}

@test "valid JSON that is not an object: warns and leaves the file" {
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '[1, 2]\n' > "${SETTINGS}"
    cp "${SETTINGS}" "${SANDBOX}/before"

    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    _has "[WARN]"
    cmp -s "${SETTINGS}" "${SANDBOX}/before"
}

@test "without jq the python3 fallback sets the font and keeps other keys" {
    command -v python3 >/dev/null 2>&1 || skip "needs python3"
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{"font_size": 14, "ui_font": "Inter"}\n' > "${SETTINGS}"

    run env PATH="$(_tools_path python3)" sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SETTINGS}")" = '{"font":"IosevkaTerm NF","font_size":14,"ui_font":"Inter"}' ]

    run env PATH="$(_tools_path python3)" sh "${FONT_CMD}" jetbrains-mono
    [ "${status}" -eq 0 ]
    [ "$(_norm "${SETTINGS}")" = '{"font":"JetBrainsMono Nerd Font","font_size":14,"ui_font":"Inter"}' ]
}

@test "without jq the python3 fallback also rejects invalid JSON" {
    command -v python3 >/dev/null 2>&1 || skip "needs python3"
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf 'not json\n' > "${SETTINGS}"
    cp "${SETTINGS}" "${SANDBOX}/before"

    run env PATH="$(_tools_path python3)" sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    _has "[WARN]"
    cmp -s "${SETTINGS}" "${SANDBOX}/before"
}

@test "neither jq nor python3: warns, leaves the file, exit 0" {
    _select herdr-app
    mkdir -p "$(dirname "${SETTINGS}")"
    printf '{"font_size": 14}\n' > "${SETTINGS}"
    cp "${SETTINGS}" "${SANDBOX}/before"

    run env PATH="$(_tools_path)" sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    _has "[WARN]"
    _has "jq"
    cmp -s "${SETTINGS}" "${SANDBOX}/before"
    [ "$(cat "${HOME}/.config/ghostty/font.conf")" = 'font-family = "IosevkaTerm NF"' ]
}

@test "help and docs mention the Herdr app font" {
    run sh "${FONT_CMD}" --help
    [ "${status}" -eq 0 ]
    _has "herdr-app/settings.json"
    grep -q 'herdr-app/settings.json' "${REPO_ROOT_REAL}/docs/tools.md"
    grep -q 'herdr-app/settings.json' "${REPO_ROOT_REAL}/docs/install.md"
}

@test "update runs font_apply, so it sets the Herdr app font too" {
    grep -q '^font_apply "${_active_font}"' "${REPO_ROOT_REAL}/src/commands/update.sh"
    grep -q 'components.sh' "${REPO_ROOT_REAL}/src/commands/update.sh"
}
