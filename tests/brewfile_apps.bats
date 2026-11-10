#!/usr/bin/env bats
# tests/brewfile_apps.bats
# Desktop apps declared in the Brewfile.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "Herdr desktop app is a macOS-only cask next to the herdr TUI formula" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"
    grep -Eq '^brew "herdr"( |$)' "${brewfile}"
    grep -Eq '^cask "herdr-app" if OS\.mac\?' "${brewfile}"
}

# _herdr_linux_step — the shell command of the Linux Herdr app install step.
_herdr_linux_step() {
    awk '/description: Install Herdr desktop app \(Linux/ { f = 1; next }
         f && /^    quiet:/ { exit }
         f && /^    command: \|/ { next }
         f { sub(/^      /, ""); print }' "${REPO_ROOT_REAL}/config/install.conf.yaml"
}

# _run_step <uname> — run the step with stub uname/curl/sh in a sandbox HOME.
_run_step() {
    SANDBOX="$(mktemp -d)"
    mkdir -p "${SANDBOX}/bin" "${SANDBOX}/home"
    printf '#!/bin/sh\nprintf "%s\\n"\n' "$1" > "${SANDBOX}/bin/uname"
    printf '#!/bin/sh\necho "curl $*" >> "%s/calls"\necho "echo installer-ran"\n' "${SANDBOX}" > "${SANDBOX}/bin/curl"
    chmod +x "${SANDBOX}/bin/uname" "${SANDBOX}/bin/curl"
    _herdr_linux_step > "${SANDBOX}/step.sh"
    [ -s "${SANDBOX}/step.sh" ]
    run env HOME="${SANDBOX}/home" XDG_DATA_HOME= PATH="${SANDBOX}/bin:${PATH}" sh "${SANDBOX}/step.sh"
}

@test "on Linux the Herdr app is installed with its official installer" {
    _run_step Linux
    [ "${status}" -eq 0 ]
    grep -Fxq 'curl -fsSL https://releases.herdr.dev/app/install.sh' "${SANDBOX}/calls"
    [ "${output}" = "installer-ran" ]
    rm -rf "${SANDBOX}"
}

@test "on Linux an installed Herdr app is not reinstalled" {
    _run_step Linux
    mkdir -p "${SANDBOX}/home/.local/share/herdr-app"
    rm -f "${SANDBOX}/calls"
    run env HOME="${SANDBOX}/home" XDG_DATA_HOME= PATH="${SANDBOX}/bin:${PATH}" sh "${SANDBOX}/step.sh"
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/calls" ]
    rm -rf "${SANDBOX}"
}

@test "on macOS the Linux step does nothing (the cask installs the app)" {
    _run_step Darwin
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX}/calls" ]
    rm -rf "${SANDBOX}"
}
