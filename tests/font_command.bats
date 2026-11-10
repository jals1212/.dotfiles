#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/font_command.bats
# Verifies `./dots font`: the machine-local terminal font choice between
# JetBrains Mono (default) and Iosevka, written to ~/.config/ghostty/font.conf
# and DOTS_FONT in ~/.config/zsh/local.zsh, with the Nerd Font cask installed
# on demand on macOS.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin"
    export NO_COLOR=1
    FONT_CONF="${HOME}/.config/ghostty/font.conf"
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    FONT_CMD="${REPO_ROOT_REAL}/src/commands/font.sh"
    BREW_LOG="${SANDBOX}/brew.log"
    export BREW_LOG
    # Never touch the host's Homebrew: default to a fake Linux uname.
    printf '#!/bin/sh\nprintf "Linux\\n"\n' > "${SANDBOX}/bin/uname"
    chmod +x "${SANDBOX}/bin/uname"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _fake_macos [installed-cask] — stub uname as Darwin and brew as a logger.
_fake_macos() {
    printf '#!/bin/sh\nprintf "Darwin\\n"\n' > "${SANDBOX}/bin/uname"
    cat > "${SANDBOX}/bin/brew" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "\${BREW_LOG}"
if [ "\$1" = "list" ]; then
    [ "\$3" = "${1:-none}" ] && exit 0
    exit 1
fi
exit 0
EOF
    chmod +x "${SANDBOX}/bin/uname" "${SANDBOX}/bin/brew"
}

@test "--current defaults to jetbrains-mono without any recorded choice" {
    run sh "${FONT_CMD}" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "jetbrains-mono" ]
}

@test "font iosevka writes font.conf, records DOTS_FONT and reports it" {
    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ "$(cat "${FONT_CONF}")" = 'font-family = "IosevkaTerm NF"' ]
    grep -Fqx 'export DOTS_FONT="${DOTS_FONT:-iosevka}"' "${LOCAL_ZSH}"

    run sh "${FONT_CMD}" --current
    [ "${output}" = "iosevka" ]
}

@test "font jetbrains-mono replaces a previous choice in place" {
    sh "${FONT_CMD}" iosevka
    run sh "${FONT_CMD}" jetbrains-mono
    [ "${status}" -eq 0 ]
    [ "$(cat "${FONT_CONF}")" = 'font-family = "JetBrainsMono Nerd Font"' ]
    [ "$(grep -c DOTS_FONT "${LOCAL_ZSH}")" -eq 1 ]
    grep -Fqx 'export DOTS_FONT="${DOTS_FONT:-jetbrains-mono}"' "${LOCAL_ZSH}"
}

@test "unknown font exits 1 and leaves the recorded choice unchanged" {
    sh "${FONT_CMD}" iosevka
    cp "${FONT_CONF}" "${SANDBOX}/font.before"
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    run sh "${FONT_CMD}" comic
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Unknown font 'comic'. Supported: jetbrains-mono iosevka"* ]]
    cmp -s "${FONT_CONF}" "${SANDBOX}/font.before"
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "font with too many arguments prints usage and exits 2" {
    run sh "${FONT_CMD}" iosevka extra
    [ "${status}" -eq 2 ]
    [ ! -e "${FONT_CONF}" ]
}

@test "--help lists both fonts and exits 0" {
    run sh "${FONT_CMD}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"jetbrains-mono"* ]]
    [[ "${output}" == *"iosevka"* ]]
}

@test "on macOS a missing Nerd Font cask is installed with brew" {
    _fake_macos
    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    grep -Fqx 'install --cask font-iosevka-term-nerd-font' "${BREW_LOG}"
}

@test "on macOS an installed Nerd Font cask is not reinstalled" {
    _fake_macos font-jetbrains-mono-nerd-font
    run sh "${FONT_CMD}" jetbrains-mono
    [ "${status}" -eq 0 ]
    run grep -q '^install' "${BREW_LOG}"
    [ "${status}" -ne 0 ]
}

@test "off macOS no brew call is made" {
    printf '#!/bin/sh\nprintf "Linux\\n"\n' > "${SANDBOX}/bin/uname"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "${BREW_LOG}"\n' > "${SANDBOX}/bin/brew"
    chmod +x "${SANDBOX}/bin/uname" "${SANDBOX}/bin/brew"
    run sh "${FONT_CMD}" iosevka
    [ "${status}" -eq 0 ]
    [ ! -e "${BREW_LOG}" ]
}

@test "ghostty config loads font.conf and no longer hard-codes a font" {
    cfg="${REPO_ROOT_REAL}/content/home/.config/ghostty/config"
    run grep -q '^font-family' "${cfg}"
    [ "${status}" -ne 0 ]
    grep -qx 'config-file = ?font.conf' "${cfg}"
}

# _bundle_casks — font casks the Brewfile declares for the sandbox HOME.
_bundle_casks() {
    env PATH="${PATH#"${SANDBOX}/bin:"}" HOME="${HOME}" \
        HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --cask --file="${REPO_ROOT_REAL}/config/Brewfile" | grep '^font-'
}

@test "Brewfile declares only the chosen font cask (jetbrains-mono by default)" {
    [ "$(/usr/bin/uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1 || skip "needs macOS Homebrew"
    [ "$(_bundle_casks)" = "font-jetbrains-mono-nerd-font" ]

    sh "${FONT_CMD}" iosevka
    [ "$(_bundle_casks)" = "font-iosevka-term-nerd-font" ]

    sh "${FONT_CMD}" jetbrains-mono
    [ "$(_bundle_casks)" = "font-jetbrains-mono-nerd-font" ]
}

@test "update asks for the font on a TTY only while none is recorded" {
    grep -q '\[ -z "$(font_recorded)" \]' "${REPO_ROOT_REAL}/src/commands/update.sh"
}

@test "dispatcher routes font and documents it in help" {
    run sh "${REPO_ROOT_REAL}/dots" help
    [[ "${output}" == *"font        Switch the terminal font (jetbrains-mono | iosevka)."* ]]
    run sh "${REPO_ROOT_REAL}/dots" font --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "jetbrains-mono" ]
}
