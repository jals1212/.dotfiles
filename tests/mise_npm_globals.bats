#!/usr/bin/env bats
# Global npm CLIs live in mise (npm: backend), so they survive Node upgrades
# instead of being tied to one node install's lib/node_modules.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MISE_CONFIG="${REPO_ROOT_REAL}/content/home/.config/mise/config.toml"

@test "mise config declares the global npm CLIs" {
    for pkg in \
        '"npm:@colbymchenry/codegraph"' \
        '"npm:@earendil-works/pi-coding-agent"' \
        '"npm:@jals1212/pi-spaces-cli"' \
        '"npm:gentle-pi"' \
        '"npm:neon"'; do
        grep -Fq "${pkg} = " "${MISE_CONFIG}"
    done
}

@test "own packages skip the release-age gate so new releases install at once" {
    grep -Fq 'minimum_release_age_excludes = ["npm:@jals1212/pi-spaces-cli"]' "${MISE_CONFIG}"
}

@test "Brewfile does not duplicate CLIs owned by mise" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"
    run grep -Eq '^brew "pi-coding-agent"' "${brewfile}"
    [ "$status" -ne 0 ]
}

@test "azure-cli and vercel are casks: homebrew-core migrated both formulae" {
    run grep -Eq '^brew "(azure-cli|vercel)"' "${REPO_ROOT_REAL}/config/Brewfile"
    [ "${status}" -ne 0 ]
    grep -Fxq 'cask "azure-cli" if OS.mac?' "${REPO_ROOT_REAL}/config/Brewfile"
}

@test "vercel is owned by Homebrew, not mise" {
    grep -Fxq 'cask "vercel" if OS.mac?' "${REPO_ROOT_REAL}/config/Brewfile"
    run grep -Fq '"npm:vercel" = ' "${MISE_CONFIG}"
    [ "$status" -ne 0 ]
}

# The npm() guard in functions.zsh, run in zsh against a fake npm that prints
# what it gets, so nothing is ever installed.
npm_guard() {
    local bin
    bin="$(mktemp -d)"
    printf '#!/bin/sh\necho "real npm $*"\n' > "${bin}/npm"
    chmod +x "${bin}/npm"
    run zsh -fc "PATH='${bin}':\$PATH; source '${REPO_ROOT_REAL}/content/home/.config/zsh/functions.zsh' 2>/dev/null; npm $*"
    rm -rf "${bin}"
}

@test "npm refuses global installs and points to mise" {
    for args in "i -g x" "install -g x" "install --global x" "-g install x" "add -g x" \
        "update -g" "up --global x" "install --location=global x" "install --location global x" "link -g"; do
        npm_guard "${args}"
        [ "$status" -eq 1 ]
        [ "$output" = "npm: global packages live in mise: mise use -g npm:<package> (command npm skips this check)" ]
    done
}

@test "npm runs everything else as it is" {
    for args in "install x" "i -D x" "uninstall -g x" "ls -g" "run test" "view x version"; do
        npm_guard "${args}"
        [ "$status" -eq 0 ]
        [ "$output" = "real npm ${args}" ]
    done
}
