#!/usr/bin/env bats
# Verifies VSCodium is the macOS default GUI editor (via duti) while the
# terminal editor stays nvim.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DUTI_FILE="${REPO_ROOT_REAL}/content/home/.config/duti/vscodium.duti"

@test "Brewfile installs VSCodium and duti, not VS Code" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"
    grep -Fq 'cask "vscodium"' "${brewfile}"
    grep -Fq 'brew "duti"' "${brewfile}"
    run grep -Fq 'visual-studio-code' "${brewfile}"
    [ "${status}" -ne 0 ]
}

@test "duti settings file only targets com.vscodium" {
    [ -f "${DUTI_FILE}" ]
    count=0
    while IFS= read -r line; do
        case "${line}" in
            '' | '#'*) continue ;;
            'com.vscodium .'*) echo "extension entry (resolves to dyn.* UTI): ${line}"; return 1 ;;
            'com.vscodium '*) count=$((count + 1)) ;;
            *) echo "unexpected line: ${line}"; return 1 ;;
        esac
    done <"${DUTI_FILE}"
    [ "${count}" -gt 0 ]
}

@test "install.conf.yaml links the duti settings file" {
    grep -A1 -E '^[[:space:]]+~/\.config/duti/vscodium\.duti:[[:space:]]*$' "${REPO_ROOT_REAL}/config/install.conf.yaml" \
        | grep -Eq '^[[:space:]]+path:[[:space:]]+content/home/\.config/duti/vscodium\.duti[[:space:]]*$'
}

@test "terminal EDITOR and VISUAL stay nvim" {
    zshenv="${REPO_ROOT_REAL}/content/home/.config/zsh/.zshenv"
    grep -Fxq 'export EDITOR="nvim"' "${zshenv}"
    grep -Fxq 'export VISUAL="nvim"' "${zshenv}"
}

@test "Finder Quick Action opens VSCodium and is linked on macOS" {
    wf="${REPO_ROOT_REAL}/content/home/Library/Services/Open in VSCodium.workflow/Contents"
    grep -Fq '<string>/Applications/VSCodium.app</string>' "${wf}/document.wflow"
    # Not `! grep`: bats ignores a negated command unless it is the last one.
    if grep -Fq 'Visual Studio Code' "${wf}/document.wflow"; then
        echo "workflow still references Visual Studio Code"
        return 1
    fi
    grep -Fq '<string>Open in VSCodium</string>' "${wf}/Info.plist"
    grep -A1 -F '"~/Library/Services/Open in VSCodium.workflow":' "${REPO_ROOT_REAL}/config/install.conf.yaml" \
        | grep -Fq 'path: "content/home/Library/Services/Open in VSCodium.workflow"'
}
