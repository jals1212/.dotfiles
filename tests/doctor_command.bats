#!/usr/bin/env bats
# tests/doctor_command.bats
# Runs `dots doctor` through the dispatcher of a sandbox copy of the repo with
# a small stubbed registry, so the exit code and the summary line are pinned
# without depending on the host's tools or on ~/ being deployed.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    REPO="${SANDBOX}/repo"
    mkdir -p "${HOME}" "${REPO}/vendor/dotbot/bin"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO}/src"
    cp "${REPO_ROOT_REAL}/dots" "${REPO}/dots"

    # Stand-in for the dotbot submodule: only its presence is checked.
    printf '#!/bin/sh\nexit 0\n' > "${REPO}/vendor/dotbot/bin/dotbot"
    chmod +x "${REPO}/vendor/dotbot/bin/dotbot"

    # Registry of three checks that depend only on the sandbox.
    printf '%s\n' \
        'DOCTOR_CHECKS="check_dotbot_submodule check_manifest_exists check_local_state"' \
        'export DOCTOR_CHECKS' >> "${REPO}/src/lib/doctor.sh"
    printf '{}\n' > "${REPO}/manifest.json"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _has / _lacks <text> — explicit output assertions (a failing [[ ]] does not
# abort a bats test on older bash).
_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1"; return 1 ;; esac; return 0; }

@test "doctor exits 0 and prints the summary when every check passes" {
    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 0 ]
    _has "[PASS] dotbot submodule"
    _has "[PASS] manifest.json exists"
    _has "[PASS] machine-local zsh state (absent; defaults apply)"
    _lacks "[FAIL]"
    printf '%s\n' "${output}" | grep -Eq 'Doctor complete · [0-9]+s'
    _has "3/3 checks passed"
}

@test "doctor exits 1 with the failure reason and no summary when a check fails" {
    rm "${REPO}/manifest.json"

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 1 ]
    _has "[PASS] dotbot submodule"
    _has "[FAIL] manifest.json exists: missing (run ./dots update)"
    _lacks "Doctor complete"
    _lacks "checks passed"
}

@test "doctor still runs every check after one fails" {
    rm "${REPO}/vendor/dotbot/bin/dotbot"

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 1 ]
    _has "[FAIL] dotbot submodule: missing dotbot/bin/dotbot"
    _has "[PASS] manifest.json exists"
    _has "[PASS] machine-local zsh state"
}

@test "doctor accepts a whitelisted DOTS_FONT and rejects any other" {
    mkdir -p "${HOME}/.config/zsh"
    printf 'export DOTS_FONT="${DOTS_FONT:-iosevka}"\n' > "${HOME}/.config/zsh/local.zsh"
    run sh "${REPO}/dots" doctor
    [ "${status}" -eq 0 ]
    _has "[PASS] machine-local zsh state"

    printf 'export DOTS_FONT="${DOTS_FONT:-comic}"\n' > "${HOME}/.config/zsh/local.zsh"
    run sh "${REPO}/dots" doctor
    [ "${status}" -eq 1 ]
    _has "[FAIL] machine-local zsh state: DOTS_FONT not whitelisted: comic"
}

@test "doctor accepts whitelisted DOTS_COMPONENTS ids and none, and rejects any other" {
    mkdir -p "${HOME}/.config/zsh"
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux herdr-tui herdr-core herdr-app ghostty}"\n' > "${HOME}/.config/zsh/local.zsh"
    run sh "${REPO}/dots" doctor
    [ "${status}" -eq 0 ]
    _has "[PASS] machine-local zsh state"

    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"\n' > "${HOME}/.config/zsh/local.zsh"
    run sh "${REPO}/dots" doctor
    [ "${status}" -eq 0 ]

    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux vim}"\n' > "${HOME}/.config/zsh/local.zsh"
    run sh "${REPO}/dots" doctor
    [ "${status}" -eq 1 ]
    _has "[FAIL] machine-local zsh state: DOTS_COMPONENTS not whitelisted: vim"
}

@test "doctor --help exits 0 without running any check" {
    run sh "${REPO}/dots" doctor --help

    [ "${status}" -eq 0 ]
    _has "dots doctor"
    _lacks "[PASS]"
    _lacks "[FAIL]"
}

@test "doctor fails when the registry is empty" {
    printf '%s\n' 'DOCTOR_CHECKS=""' >> "${REPO}/src/lib/doctor.sh"

    run sh "${REPO}/dots" doctor

    [ "${status}" -eq 1 ]
    _has "did not export DOCTOR_CHECKS"
}

@test "every registered check is a defined function" {
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/doctor.sh"

    [ -n "${DOCTOR_CHECKS}" ]
    for fn in ${DOCTOR_CHECKS}; do
        if ! command -v "${fn}" >/dev/null 2>&1; then
            echo "registered but undefined: ${fn}"
            return 1
        fi
    done
}

# _nvim_sandbox <active-theme-flavor-link> — repo with two nvim palettes, a
# manifest naming kanagawa/wave, and the theme link pointing at <link>.
_nvim_sandbox() {
    mkdir -p "${REPO}/content/assets/palettes/nvim" "${REPO}/content/home/.config/nvim/lua"
    : > "${REPO}/content/assets/palettes/nvim/kanagawa-wave.lua"
    : > "${REPO}/content/assets/palettes/nvim/catppuccin-mocha.lua"
    printf '{\n  "theme": "kanagawa",\n  "flavor": "wave"\n}\n' > "${REPO}/manifest.json"
    printf '%s\n' 'DOCTOR_CHECKS="check_nvim_theme_link"' 'export DOCTOR_CHECKS' >> "${REPO}/src/lib/doctor.sh"
    if [ -n "${1:-}" ]; then
        ln -s "${REPO}/content/assets/palettes/nvim/$1.lua" "${REPO}/content/home/.config/nvim/lua/dots-theme.lua"
    fi
}

@test "doctor passes when the nvim theme link points at the active palette" {
    _nvim_sandbox kanagawa-wave

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 0 ]
    _has "[PASS] nvim theme link (kanagawa/wave)"
    _has "1/1 checks passed"
}

@test "doctor fails when the nvim theme link points at another flavor" {
    _nvim_sandbox catppuccin-mocha

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 1 ]
    _has "[FAIL] nvim theme link: points at catppuccin-mocha.lua but the active theme is kanagawa/wave"
    _lacks "checks passed"
}

@test "doctor fails when the nvim theme link is missing" {
    _nvim_sandbox

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 1 ]
    _has "[FAIL] nvim theme link: missing (run ./dots theme kanagawa wave)"
}

@test "doctor fails when the nvim theme link is a regular file" {
    _nvim_sandbox
    : > "${REPO}/content/home/.config/nvim/lua/dots-theme.lua"

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 1 ]
    _has "[FAIL] nvim theme link: not a symlink: ${REPO}/content/home/.config/nvim/lua/dots-theme.lua"
    _lacks "[PASS] nvim theme link"
    _lacks "checks passed"
    # doctor only reports: the regular file is still there, untouched.
    [ -f "${REPO}/content/home/.config/nvim/lua/dots-theme.lua" ]
    [ ! -L "${REPO}/content/home/.config/nvim/lua/dots-theme.lua" ]
}

@test "doctor skips the nvim theme link without a manifest" {
    _nvim_sandbox
    rm "${REPO}/manifest.json"

    run sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 0 ]
    _has "[SKIP] nvim theme link: no active theme in manifest.json"
}

@test "the real registry includes check_nvim_theme_link and doctor --help mentions it" {
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/doctor.sh"
    case " ${DOCTOR_CHECKS} " in *" check_nvim_theme_link "*) ;; *) echo "not registered"; return 1 ;; esac

    run sh "${REPO_ROOT_REAL}/dots" doctor --help
    _has "Nvim theme         : dots-theme.lua link points at the active theme/flavor palette"
}
