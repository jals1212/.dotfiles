#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/theme_command.bats
# Runs `dots theme` end to end against a sandbox copy of the repo: the dotbot
# wrapper is stubbed, so nothing is linked and no repo file is rewritten.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin" "${SANDBOX}/repo"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO_ROOT_REAL}/content" "${SANDBOX}/repo/"
    cp "${REPO_ROOT_REAL}/dots" "${SANDBOX}/repo/dots"
    # The developer's real (gitignored) theme link must not leak into the
    # sandbox: it is absolute, so writing through it would hit the real repo.
    rm -f "${SANDBOX}/repo/content/home/.config/nvim/lua/dots-theme.lua"

    # Replace the real dotbot run with a no-op, in the sandbox copy only.
    printf '%s\n' \
        'dotbot_check_submodules() { return 0; }' \
        'dotbot_theme_apply() { return 0; }' \
        >> "${SANDBOX}/repo/src/lib/dotbot.sh"

    # Keep host tools (bat cache, tmux, herdr) out of the run.
    printf '#!/bin/sh\nexit 0\n' > "${SANDBOX}/bin/bat"
    printf '#!/bin/sh\nexit 1\n' > "${SANDBOX}/bin/tmux"
    printf '#!/bin/sh\nexit 1\n' > "${SANDBOX}/bin/herdr"
    chmod +x "${SANDBOX}/bin/bat" "${SANDBOX}/bin/tmux" "${SANDBOX}/bin/herdr"
    export PATH="${SANDBOX}/bin:${PATH}"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "dots theme <theme> <flavor> reports 'Theme set' exactly once" {
    run --separate-stderr sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha
    all="${output}"$'\n'"${stderr}"
    echo "${all}"

    [ "${status}" -eq 0 ]
    [ "$(printf '%s\n' "${all}" | grep -c 'Theme set')" -eq 1 ]
    [[ "${all}" == *"catppuccin/mocha"* ]] || return 1
    grep -Fq '"theme": "catppuccin"' "${SANDBOX}/repo/manifest.json"
    grep -Fq '"flavor": "mocha"' "${SANDBOX}/repo/manifest.json"
}

@test "dots theme rejects an unknown flavor without writing a manifest" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin nope

    [ "${status}" -ne 0 ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}

@test "dots theme writes the slim manifest with every key" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa wave

    [ "${status}" -eq 0 ]
    manifest="${SANDBOX}/repo/manifest.json"
    grep -Fq '"version": "' "${manifest}"
    grep -Fq '"theme": "kanagawa"' "${manifest}"
    grep -Fq '"flavor": "wave"' "${manifest}"
    grep -Fq '"prompt": "starship"' "${manifest}"
    grep -Eq '"applied_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z"' "${manifest}"
    [ "$(grep -c '":' "${manifest}")" -eq 5 ]
}

@test "dots theme keeps the manifest prompt and replaces theme and flavor" {
    printf '{\n  "version": "3.1.0",\n  "theme": "kanagawa",\n  "flavor": "wave",\n  "prompt": "p10k",\n  "applied_at": "2020-01-01T00:00:00Z"\n}\n' \
        > "${SANDBOX}/repo/manifest.json"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin latte

    [ "${status}" -eq 0 ]
    manifest="${SANDBOX}/repo/manifest.json"
    grep -Fq '"theme": "catppuccin"' "${manifest}"
    grep -Fq '"flavor": "latte"' "${manifest}"
    grep -Fq '"prompt": "p10k"' "${manifest}"
    run ! grep -Fq '2020-01-01' "${manifest}"
}

@test "dots theme --current prints the pair recorded in the manifest" {
    sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin frappe >/dev/null 2>&1

    run --separate-stderr sh "${SANDBOX}/repo/src/commands/theme.sh" --current

    [ "${status}" -eq 0 ]
    [ "${output}" = "catppuccin frappe" ]
}

@test "dots theme with an unknown theme or flavor leaves an existing manifest unchanged" {
    manifest="${SANDBOX}/repo/manifest.json"
    printf '{\n  "version": "3.1.0",\n  "theme": "kanagawa",\n  "flavor": "wave",\n  "prompt": "p10k",\n  "applied_at": "2020-01-01T00:00:00Z"\n}\n' \
        > "${manifest}"
    cp "${manifest}" "${SANDBOX}/manifest.before"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" nosuchtheme dragon
    [ "${status}" -ne 0 ]
    cmp "${manifest}" "${SANDBOX}/manifest.before"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa mocha
    [ "${status}" -ne 0 ]
    cmp "${manifest}" "${SANDBOX}/manifest.before"
}

# _nvim_link — the repo-side Neovim theme link the switcher maintains.
_nvim_link() { printf '%s' "${SANDBOX}/repo/content/home/.config/nvim/lua/dots-theme.lua"; }
_nvim_palette() { printf '%s' "${SANDBOX}/repo/content/assets/palettes/nvim/$1.lua"; }

@test "dots theme points the nvim theme link at the new flavor's palette" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha
    [ "${status}" -eq 0 ]
    [ -L "$(_nvim_link)" ]
    [ "$(readlink -f "$(_nvim_link)")" = "$(readlink -f "$(_nvim_palette catppuccin-mocha)")" ]

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa dragon
    [ "${status}" -eq 0 ]
    [ -L "$(_nvim_link)" ]
    [ "$(readlink -f "$(_nvim_link)")" = "$(readlink -f "$(_nvim_palette kanagawa-dragon)")" ]
    grep -Fq 'colorscheme = "kanagawa-dragon"' "$(_nvim_link)"
}

@test "dots theme never replaces a real file at the nvim theme link" {
    printf -- '-- mine\n' > "$(_nvim_link)"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa lotus

    [ "${status}" -ne 0 ]
    [ ! -L "$(_nvim_link)" ]
    [ "$(cat "$(_nvim_link)")" = "-- mine" ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}

@test "dots theme fails without writing a manifest when the nvim palette is missing" {
    rm "$(_nvim_palette catppuccin-latte)"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin latte

    [ "${status}" -ne 0 ]
    [ ! -e "$(_nvim_link)" ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}

@test "every theme flavor has an nvim palette naming its colorscheme and plugin" {
    n=0
    for cfg in "${REPO_ROOT_REAL}"/content/themes/*-*.yaml; do
        name="$(basename "${cfg}" .yaml)"
        palette="${REPO_ROOT_REAL}/content/assets/palettes/nvim/${name}.lua"
        [ -f "${palette}" ]
        grep -Fq "colorscheme = \"${name}\"" "${palette}"
        grep -Eq 'plugin = "[^"]+/[^"]+"' "${palette}"
        n=$((n + 1))
    done
    [ "${n}" -eq 7 ]
}

@test "the nvim theme link is untracked machine state" {
    run git -C "${REPO_ROOT_REAL}" check-ignore -q content/home/.config/nvim/lua/dots-theme.lua
    [ "${status}" -eq 0 ]
}

# --- nvim link is prepared before dotbot changes anything -------------------

# _dotbot_marker — a dotbot stub that records it ran (and can be told to fail).
_dotbot_marker() {
    printf '%s\n' \
        "dotbot_theme_apply() { echo ran > '${SANDBOX}/dotbot-ran'; return ${1:-0}; }" \
        >> "${SANDBOX}/repo/src/lib/dotbot.sh"
}

@test "dots theme refuses a real file at the nvim link before dotbot runs" {
    _dotbot_marker 0
    printf -- '-- mine\n' > "$(_nvim_link)"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa lotus

    [ "${status}" -ne 0 ]
    [ ! -e "${SANDBOX}/dotbot-ran" ]
    [ "$(cat "$(_nvim_link)")" = "-- mine" ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}

@test "dots theme finds a missing nvim palette before dotbot runs" {
    _dotbot_marker 0
    rm "$(_nvim_palette catppuccin-latte)"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin latte

    [ "${status}" -ne 0 ]
    [ ! -e "${SANDBOX}/dotbot-ran" ]
    [ ! -e "$(_nvim_link)" ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}

@test "dots theme leaves the nvim link alone when dotbot fails" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha
    [ "${status}" -eq 0 ]
    _dotbot_marker 1

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa dragon

    [ "${status}" -ne 0 ]
    [ -e "${SANDBOX}/dotbot-ran" ]
    [ "$(readlink -f "$(_nvim_link)")" = "$(readlink -f "$(_nvim_palette catppuccin-mocha)")" ]
    grep -Fq '"flavor": "mocha"' "${SANDBOX}/repo/manifest.json"
}

# --- bat cache rebuild: batcat when only that exists --------------------------

# _bat_shims <name>... — recording shims for the named commands; PATH is cut
# down to the sandbox bin plus the system directories so no host bat leaks in.
_bat_shims() {
    rm -f "${SANDBOX}/bin/bat" "${SANDBOX}/bin/batcat"
    local name
    for name in "$@"; do
        printf '#!/bin/sh\necho "%s $*" >> "%s/bat-calls"\n' "${name}" "${SANDBOX}" > "${SANDBOX}/bin/${name}"
        chmod +x "${SANDBOX}/bin/${name}"
    done
    export PATH="${SANDBOX}/bin:/usr/bin:/bin"
}

@test "dots theme rebuilds the bat cache with batcat when only batcat exists" {
    _bat_shims batcat

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha

    [ "${status}" -eq 0 ]
    [ "$(cat "${SANDBOX}/bat-calls")" = "batcat cache --build" ]
    [[ "${output}" != *"bat not installed"* ]] || return 1
}

@test "dots theme keeps using bat when both bat and batcat exist" {
    _bat_shims bat batcat

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha

    [ "${status}" -eq 0 ]
    [ "$(cat "${SANDBOX}/bat-calls")" = "bat cache --build" ]
}

@test "dots theme skips the bat cache with a warning when neither exists" {
    _bat_shims

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha

    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/bat-calls" ]
    [[ "${output}" == *"bat not installed; skipping bat cache rebuild"* ]] || return 1
}

@test "the dotbot bat cache step builds with batcat only when bat is missing" {
    local cmd
    cmd="$(sed -n 's/^    command: \(.*bat.*cache --build.*\)$/\1/p' "${REPO_ROOT_REAL}/config/install.conf.yaml")"
    [ -n "${cmd}" ]

    _bat_shims batcat
    run env PATH="${PATH}" sh -c "${cmd}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${SANDBOX}/bat-calls")" = "batcat cache --build" ]

    rm -f "${SANDBOX}/bat-calls"
    _bat_shims bat batcat
    run env PATH="${PATH}" sh -c "${cmd}"
    [ "${status}" -eq 0 ]
    [ "$(cat "${SANDBOX}/bat-calls")" = "bat cache --build" ]

    rm -f "${SANDBOX}/bat-calls"
    _bat_shims
    run env PATH="${PATH}" sh -c "${cmd}"
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/bat-calls" ]
}
