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

@test "every tmux @plugin line, in any form, is preceded by a 40-hex '# pin <sha>' line" {
    # Any non-comment line with an @plugin token counts, indented, double
    # quoted, set-option, with a trailing comment or not.
    run awk '
        { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
        line ~ /^# pin [0-9a-f]+$/ && length(line) == 46 { sha = 1; next }
        line !~ /^#/ && line ~ /(^|[ \t])@plugin([ \t]|$)/ {
            n++
            if (!sha) { print "unpinned: " $0; bad = 1 }
            sha = 0
            next
        }
        { sha = 0 }
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

@test "pin-plugins removes a fresh clone whose pin cannot be checked out and exits 1" {
    _fixture_remote owner/repo >/dev/null
    _fixture_conf "0000000000000000000000000000000000000000"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"pin-plugins: owner/repo:"* ]] || return 1
    [ ! -e "${SANDBOX}/plugins/repo" ]
}

@test "pin-plugins exits 1 for a bad pin on an existing checkout and keeps it" {
    _fixture_remote owner/repo >/dev/null
    _fixture_conf "0000000000000000000000000000000000000000"
    git clone -q "${SANDBOX}/remote/owner/repo" "${SANDBOX}/plugins/repo"
    echo local >"${SANDBOX}/plugins/repo/untracked"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"pin-plugins: owner/repo:"* ]] || return 1
    [ "$(cat "${SANDBOX}/plugins/repo/file")" = "two" ]
    [ "$(cat "${SANDBOX}/plugins/repo/untracked")" = "local" ]
}

@test "pin-plugins clones indented, double-quoted, set-option and commented @plugin lines at their pins" {
    local sha_a sha_b sha_c
    sha_a="$(_fixture_remote owner/repo)"
    sha_b="$(_fixture_remote owner/other)"
    sha_c="$(_fixture_remote owner/third)"
    cat >"${SANDBOX}/tmux.conf" <<EOF
  # pin ${sha_a}
    set -g @plugin "owner/repo"
# pin ${sha_b}
set-option -g @plugin 'owner/other' # note
	# pin ${sha_c}
	set  -g  @plugin  "owner/third"   # note
EOF

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 0 ]
    [ -z "${stderr}" ]
    [ "$(git -C "${SANDBOX}/plugins/repo" rev-parse HEAD)" = "${sha_a}" ]
    [ "$(git -C "${SANDBOX}/plugins/other" rev-parse HEAD)" = "${sha_b}" ]
    [ "$(git -C "${SANDBOX}/plugins/third" rev-parse HEAD)" = "${sha_c}" ]
}

@test "pin-plugins exits 1 naming an unpinned @plugin line and still pins the others" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    _fixture_remote owner/other >/dev/null
    cat >"${SANDBOX}/tmux.conf" <<EOF
# pin ${sha}
set -g @plugin 'owner/repo'
  set -g @plugin "owner/other"
EOF

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"pin-plugins: owner/other:"* ]] || return 1
    [ "$(git -C "${SANDBOX}/plugins/repo" rev-parse HEAD)" = "${sha}" ]
    [ ! -e "${SANDBOX}/plugins/other" ]
}

@test "pin-plugins exits 1 for a short or non-hex pin without cloning" {
    _fixture_remote owner/repo >/dev/null
    _fixture_conf "abc123"

    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"pin-plugins: owner/repo:"* ]] || return 1
    [ ! -e "${SANDBOX}/plugins/repo" ]
}

@test "pin-plugins exits 1 for an @plugin line it cannot parse, naming the line" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    local forms=(
        "set -g @plugin owner/repo"
        "set -ag @plugin 'owner/repo'"
        "set -g @plugin 'owner/repo' 'extra'"
        "set -g @plugin ''"
    )
    local form
    for form in "${forms[@]}"; do
        printf '# pin %s\n%s\n' "${sha}" "${form}" >"${SANDBOX}/tmux.conf"

        DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

        [ "${status}" -eq 1 ] || { echo "accepted: ${form}" >&3; return 1; }
        [[ "${stderr}" == *"${form}"* ]] || { echo "not named: ${form}: ${stderr}" >&3; return 1; }
        [ ! -e "${SANDBOX}/plugins" ] || { echo "created for: ${form}" >&3; return 1; }
    done
}

@test "pin-plugins rejects specs that are not owner/repo and creates nothing outside the plugins dir" {
    local sha
    sha="$(_fixture_remote owner/repo)"
    local specs=("o/.." "../x" "./x" "a/b/c" "/x" "x/" "o/ev il" 'o/$HOME' "o/..repo/x" "owner/repo#main")
    local spec before after
    for spec in "${specs[@]}"; do
        printf "# pin %s\nset -g @plugin '%s'\n" "${sha}" "${spec}" >"${SANDBOX}/tmux.conf"
        before="$(cd "${SANDBOX}" && find . | sort)"

        DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/remote" run --separate-stderr sh "${PIN_SCRIPT}" "${SANDBOX}/tmux.conf" "${SANDBOX}/plugins"

        after="$(cd "${SANDBOX}" && find . | sort)"
        [ "${status}" -eq 1 ] || { echo "accepted: ${spec}" >&3; return 1; }
        [[ "${stderr}" == *"${spec}"* ]] || { echo "not named: ${spec}: ${stderr}" >&3; return 1; }
        [ "${before}" = "${after}" ] || { echo "changed tree for: ${spec}" >&3; return 1; }
    done
}

@test "pin-plugins reads every @plugin entry of the real tmux.conf" {
    # Dry parse: with an unreachable remote and empty plugin dir every entry
    # that parses and is pinned fails only at the clone, once. An entry of any
    # form the script cannot parse or that has no pin reports something else.
    DOTS_TMUX_PLUGIN_BASE_URL="${SANDBOX}/none" run --separate-stderr sh "${PIN_SCRIPT}" "${TMUX_CONF}" "${SANDBOX}/plugins"

    [ "${status}" -eq 1 ]
    local declared reported clone_failures
    declared="$(grep -Ec '^[[:space:]]*[^#[:space:]].*[[:space:]]@plugin([[:space:]]|$)' "${TMUX_CONF}")"
    reported="$(printf '%s\n' "${stderr}" | grep -c '^pin-plugins:')"
    clone_failures="$(printf '%s\n' "${stderr}" | grep -c '^pin-plugins: .*: cannot clone ')"
    [ "${declared}" -gt 0 ]
    [ "${declared}" -eq "${reported}" ]
    [ "${declared}" -eq "${clone_failures}" ]
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
