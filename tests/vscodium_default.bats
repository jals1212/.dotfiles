#!/usr/bin/env bats
# Verifies VSCodium is the macOS default GUI editor (via duti) while the
# terminal editor stays nvim.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DUTI_FILE="${REPO_ROOT_REAL}/content/home/.config/duti/vscodium.duti"

@test "Brewfile installs VSCodium and duti only when vscodium is selected, not VS Code" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"
    grep -Eq '^cask "vscodium" if OS\.mac\? && dots_components\.include\?\("vscodium"\)' "${brewfile}"
    grep -Eq '^brew "duti" if OS\.mac\? && dots_components\.include\?\("vscodium"\)' "${brewfile}"
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

@test "install.conf.yaml links the duti settings file, on macOS with vscodium selected" {
    conf="${REPO_ROOT_REAL}/config/install.conf.yaml"
    grep -A1 -E '^[[:space:]]+~/\.config/duti/vscodium\.duti:[[:space:]]*$' "${conf}" \
        | grep -Eq '^[[:space:]]+path:[[:space:]]+content/home/\.config/duti/vscodium\.duti[[:space:]]*$'
    grep -A3 -E '^[[:space:]]+~/\.config/duti/vscodium\.duti:[[:space:]]*$' "${conf}" \
        | grep -Fq 'component-selected.sh vscodium'
}

@test "terminal EDITOR and VISUAL come from DOTS_EDITOR (nvim by default), set after local.zsh" {
    zshenv="${REPO_ROOT_REAL}/content/home/.config/zsh/.zshenv"
    grep -Fxq 'export EDITOR="${DOTS_EDITOR:-nvim}"' "${zshenv}"
    grep -Fxq 'export VISUAL="$EDITOR"' "${zshenv}"
    src_n="$(grep -n 'source "$ZDOTDIR/local.zsh"' "${zshenv}" | cut -d: -f1)"
    ed_n="$(grep -n '^export EDITOR=' "${zshenv}" | cut -d: -f1)"
    [ "${ed_n}" -gt "${src_n}" ]
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
    # gated like the duti link: it reuses the &if_vscodium predicate (macOS + vscodium selected)
    grep -A3 -F '"~/Library/Services/Open in VSCodium.workflow":' "${REPO_ROOT_REAL}/config/install.conf.yaml" \
        | grep -Fq 'if: *if_vscodium'
    grep -F '&if_vscodium' "${REPO_ROOT_REAL}/config/install.conf.yaml" \
        | grep -Fq 'component-selected.sh vscodium'
}

@test "the duti default-app step runs through the shared script and only applies on macOS with vscodium selected" {
    conf="${REPO_ROOT_REAL}/config/install.conf.yaml"
    grep -Fq 'sh content/home/.config/dots/duti-apply.sh' "${conf}"
    script="${REPO_ROOT_REAL}/content/home/.config/dots/duti-apply.sh"
    [ -f "${script}" ]
    grep -Fq 'component-selected' "${script}" || grep -Fq 'components_has vscodium' "${script}"
    grep -Fq 'Darwin' "${script}"
}

@test "duti-apply.sh does nothing while vscodium is not selected" {
    sandbox="$(mktemp -d)"
    mkdir -p "${sandbox}/home/.config/zsh" "${sandbox}/bin"
    printf '#!/bin/sh\necho duti "$@" >> "%s/calls"\n' "${sandbox}" > "${sandbox}/bin/duti"
    printf '#!/bin/sh\necho open "$@" >> "%s/calls"\n' "${sandbox}" > "${sandbox}/bin/open"
    printf '#!/bin/sh\necho Darwin\n' > "${sandbox}/bin/uname"
    chmod +x "${sandbox}"/bin/*
    run env HOME="${sandbox}/home" PATH="${sandbox}/bin:/usr/bin:/bin" sh "${REPO_ROOT_REAL}/content/home/.config/dots/duti-apply.sh"
    status_unselected="${status}"
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux nvim fresh}"\n' > "${sandbox}/home/.config/zsh/local.zsh"
    run env HOME="${sandbox}/home" PATH="${sandbox}/bin:/usr/bin:/bin" sh "${REPO_ROOT_REAL}/content/home/.config/dots/duti-apply.sh"
    status_other="${status}"
    calls=0
    [ ! -e "${sandbox}/calls" ] || calls=1
    rm -rf "${sandbox}"
    [ "${status_unselected}" -eq 0 ]
    [ "${status_other}" -eq 0 ]
    [ "${calls}" -eq 0 ]
}
