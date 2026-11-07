#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/dependency_pins.bats
# Guardrails for third-party dependencies outside the submodules: every tmux
# plugin (TPM included) is pinned to a commit like the zsh plugins, each
# `trusted:` Brewfile tap says why and trusts only what the Brewfile installs,
# and the Homebrew installer is fetched by commit, not by branch.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TMUX_CONF="${REPO_ROOT_REAL}/content/home/.config/tmux/tmux.conf"
PIN_SCRIPT="${REPO_ROOT_REAL}/content/home/.config/tmux/scripts/pin-plugins.sh"
BREWFILE="${REPO_ROOT_REAL}/config/Brewfile"
INSTALL_CONF="${REPO_ROOT_REAL}/config/install.conf.yaml"

setup() {
    SANDBOX="$(mktemp -d)"
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _git — git with a fixed identity, quiet, for the fixture repositories.
_git() {
    git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"
}

# _fixture_remote <owner/repo> — a two-commit repo under ${SANDBOX}/remote;
# prints the first commit (the one the fixture conf pins).
_fixture_remote() {
    local dir="${SANDBOX}/remote/$1"
    mkdir -p "${dir}"
    _git -C "${dir}" init -q
    echo one >"${dir}/file"
    _git -C "${dir}" add file
    _git -C "${dir}" commit -q -m one
    _git -C "${dir}" rev-parse HEAD
    echo two >"${dir}/file"
    _git -C "${dir}" commit -q -a -m two
}

# _fixture_conf <sha> — a tmux.conf with one pinned plugin.
_fixture_conf() {
    cat >"${SANDBOX}/tmux.conf" <<EOF
set -g @continuum-restore 'off'
# pin $1
set -g @plugin 'owner/repo'
EOF
}

# ── tmux plugins ─────────────────────────────────────────────────────────────

@test "every tmux @plugin is preceded by a 40-hex '# pin <sha>' line" {
    run awk '
        /^set -g @plugin / {
            n++
            if (sha == "") { print "unpinned: " $0; bad = 1 }
            sha = ""
            next
        }
        /^# pin [0-9a-f]{40}$/ { sha = $3; next }
        { sha = "" }
        END { if (n == 0) { print "no @plugin lines"; bad = 1 } exit bad }
    ' "${TMUX_CONF}"
    echo "${output}" >&3
    [ "${status}" -eq 0 ]
}

@test "tmux.conf has no unpinned git clone of TPM and runs the pin script before TPM" {
    run grep -q 'git clone' "${TMUX_CONF}"
    [ "${status}" -eq 1 ]
    local pin_line tpm_line
    pin_line="$(grep -n 'pin-plugins.sh' "${TMUX_CONF}" | head -1 | cut -d: -f1)"
    tpm_line="$(grep -n "^run '.*tpm/tpm'" "${TMUX_CONF}" | head -1 | cut -d: -f1)"
    [ -n "${pin_line}" ]
    [ -n "${tpm_line}" ]
    [ "${pin_line}" -lt "${tpm_line}" ]
}

@test "install.conf.yaml links the pin script" {
    grep -q '~/.config/tmux/scripts/pin-plugins.sh: content/home/.config/tmux/scripts/pin-plugins.sh' "${INSTALL_CONF}"
    [ -f "${PIN_SCRIPT}" ]
}

@test "pin-plugins clones a missing plugin at its pinned commit, not the branch tip" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    _fixture_conf "${sha}"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 0 ]
    [ "$(git -C "${SANDBOX}/plugins/repo" rev-parse HEAD)" = "${sha}" ]
    [ "$(cat "${SANDBOX}/plugins/repo/file")" = "one" ]
}

@test "pin-plugins moves an existing plugin checkout to its pinned commit" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    _fixture_conf "${sha}"
    git clone -q "${SANDBOX}/remote/owner/repo" "${SANDBOX}/plugins/repo"
    [ "$(cat "${SANDBOX}/plugins/repo/file")" = "two" ]

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 0 ]
    [ "$(git -C "${SANDBOX}/plugins/repo" rev-parse HEAD)" = "${sha}" ]
}

@test "pin-plugins leaves a checkout already at its pin untouched" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    _fixture_conf "${sha}"
    git clone -q "${SANDBOX}/remote/owner/repo" "${SANDBOX}/plugins/repo"
    git -C "${SANDBOX}/plugins/repo" checkout -q "${sha}"
    echo local >"${SANDBOX}/plugins/repo/untracked"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/does-not-exist" run sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
    [ "$(cat "${SANDBOX}/plugins/repo/untracked")" = "local" ]
}

@test "pin-plugins fails loudly for a pin that does not exist upstream and keeps the checkout" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    _fixture_conf "0000000000000000000000000000000000000000"
    git clone -q "${SANDBOX}/remote/owner/repo" "${SANDBOX}/plugins/repo"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"owner/repo"* ]] || return 1
    [ "$(cat "${SANDBOX}/plugins/repo/file")" = "two" ]
}

@test "pin-plugins skips an @plugin with no pin line and reports it" {
    printf "set -g @plugin 'owner/repo'\n" >"${SANDBOX}/tmux.conf"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -ne 0 ]
    [[ "${stderr}" == *"owner/repo"* ]] || return 1
    [ ! -e "${SANDBOX}/plugins/repo" ]
}

@test "pin-plugins reads every @plugin entry of the real tmux.conf" {
    # Dry parse: with an unreachable remote and empty plugin dir every plugin
    # is reported once, in order, so the script reads every conf entry.
    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/none" run --separate-stderr sh "${PIN_SCRIPT}" "${TMUX_CONF}" "${SANDBOX}/plugins"

    [ "${status}" -ne 0 ]
    local declared reported
    declared="$(grep -c '^set -g @plugin ' "${TMUX_CONF}")"
    reported="$(printf '%s\n' "${stderr}" | grep -c 'pin-plugins:')"
    [ "${declared}" -eq "${reported}" ]
}

# ── Brewfile trusted taps ────────────────────────────────────────────────────

@test "no tap trusts the whole tap: trust is scoped to the items the Brewfile installs" {
    run grep -E '^tap .*trusted: *true' "${BREWFILE}"
    [ "${status}" -eq 1 ]
}

@test "every trusted tap carries a '# trusted:' reason comment on the line above" {
    run awk '
        /^tap .*trusted:/ { n++; if (prev !~ /^# trusted: ./) { print "no reason above: " $0; bad = 1 } }
        { prev = $0 }
        END { if (n == 0) { print "no trusted taps"; bad = 1 } exit bad }
    ' "${BREWFILE}"
    echo "${output}" >&3
    [ "${status}" -eq 0 ]
}

@test "every item a trusted tap lists is installed by a brew/cask line of that tap" {
    local line tap name list
    while IFS= read -r line; do
        tap="$(printf '%s' "${line}" | sed -E 's/^tap "([^"]+)".*/\1/')"
        # Brewfile tap names are user/repo[/homebrew-]; formula refs use user/repo/name.
        list="$(printf '%s' "${line}" | sed -E 's/.*(formulae|casks): *\[([^]]*)\].*/\2/' | tr -d '" ' | tr ',' '\n')"
        [ -n "${list}" ]
        for name in ${list}; do
            grep -Eq "^(brew|cask) \"${tap}/${name}\"" "${BREWFILE}" || {
                echo "trusted ${tap}/${name} is not installed by the Brewfile" >&3
                return 1
            }
        done
    done < <(grep -E '^tap .*trusted:' "${BREWFILE}")
}

# ── Homebrew installer ───────────────────────────────────────────────────────

@test "the Homebrew installer is fetched by a 40-hex commit, never HEAD or a branch" {
    grep -Eq 'raw\.githubusercontent\.com/Homebrew/install/[0-9a-f]{40}/install\.sh' "${INSTALL_CONF}"
    run grep -E 'Homebrew/install/(HEAD|master|main)/' "${INSTALL_CONF}"
    [ "${status}" -eq 1 ]
}

@test "the pinned installer line says how to bump it" {
    grep -Eiq '^# .*bump.*Homebrew/install|^# .*Homebrew/install.*bump' "${INSTALL_CONF}"
}
