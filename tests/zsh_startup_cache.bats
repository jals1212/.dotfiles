#!/usr/bin/env bats
# tests/zsh_startup_cache.bats
# zsh startup: the generated init scripts of zoxide, mise and starship are
# cached under $XDG_CACHE_HOME/zsh and regenerated when the tool binary changes,
# a stale or corrupt cache falls back to the live eval, and no `$(uname)` fork
# is left in the zsh config. Every case runs in a sandbox HOME with fake tool
# binaries on PATH and `zsh -f`, so no host startup file or real tool leaks in.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ZSH_DIR="${REPO_ROOT_REAL}/content/home/.config/zsh"

setup() {
    command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
    ZSH_BIN="$(command -v zsh)"
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
    export HOME="${SANDBOX}/home"
    SHIMS="${SANDBOX}/shims"
    COUNTS="${SANDBOX}/counts"
    CACHE="${SANDBOX}/cache"
    mkdir -p "${HOME}" "${SHIMS}" "${COUNTS}"
    ZSH_EXTRA_ENV=()
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _tool <name> <tag> [dir] — a fake <name> whose init output defines fn_<name>
# printing <tag>; it records every run in ${COUNTS}/<name>. Its mtime is pinned
# so a later _tool call with another mtime stands for "the binary changed".
_tool() {
    local name=$1 tag=$2 dir=${3:-${SHIMS}} stamp=${4:-202001010000}
    mkdir -p "${dir}"
    cat >"${dir}/${name}" <<EOF
#!/bin/sh
echo run >> "${COUNTS}/${name}"
echo 'fn_${name}() { echo ${tag}; }'
EOF
    chmod +x "${dir}/${name}"
    touch -t "${stamp}" "${dir}/${name}"
}

# _runs <name> — how many times the fake <name> ran.
_runs() { if [ -e "${COUNTS}/$1" ]; then wc -l <"${COUNTS}/$1" | tr -d ' '; else echo 0; fi; }

# _zsh <script> — run in `zsh -f` with only the shims and the system dirs on PATH.
_zsh() {
    run env -i HOME="${HOME}" PATH="${PATH_UNDER_TEST:-${SHIMS}:/usr/bin:/bin}" \
        XDG_CACHE_HOME="${XDG_CACHE_HOME_UNDER_TEST:-${CACHE}}" "${ZSH_EXTRA_ENV[@]}" \
        "${ZSH_BIN}" -f -c "$1"
}

# _load — functions.zsh holds the cache helper; tools.zsh and prompt.zsh use it.
_load() { printf '%s' "source '${ZSH_DIR}/functions.zsh'; source '${ZSH_DIR}/tools.zsh'; source '${ZSH_DIR}/prompt.zsh'; $1"; }

# --- 1. no uname forks --------------------------------------------------------

@test "the zsh config and .zprofile run no uname (the shell already knows \$OSTYPE)" {
    run grep -rn 'uname' "${ZSH_DIR}"
    echo "${output}"

    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
}

# --- 2. zoxide and starship: cached, reused, regenerated ----------------------

@test "the first shell writes the init caches and the second reuses them without running the tools" {
    _tool zoxide v1
    _tool starship v1

    _zsh "$(_load 'fn_zoxide; fn_starship')"
    [ "${status}" -eq 0 ]
    [ "${output}" = $'v1\nv1' ]
    [ -s "${CACHE}/zsh/init-zoxide.zsh" ]
    [ -s "${CACHE}/zsh/init-starship.zsh" ]
    [ "$(_runs zoxide)" -eq 1 ]
    [ "$(_runs starship)" -eq 1 ]

    _zsh "$(_load 'fn_zoxide; fn_starship')"
    [ "${status}" -eq 0 ]
    [ "${output}" = $'v1\nv1' ]
    [ "$(_runs zoxide)" -eq 1 ]
    [ "$(_runs starship)" -eq 1 ]
}

@test "the cache is regenerated when the tool binary changes (mtime)" {
    _tool zoxide v1
    _zsh "$(_load 'fn_zoxide')"
    [ "${output}" = "v1" ]

    _tool zoxide v2 "${SHIMS}" 202101010000
    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "v2" ]
    [ "$(_runs zoxide)" -eq 2 ]

    _zsh "$(_load 'fn_zoxide')"
    [ "${output}" = "v2" ]
    [ "$(_runs zoxide)" -eq 2 ]
}

@test "the cache is regenerated when another binary of the same name comes first on PATH" {
    _tool zoxide v1
    _zsh "$(_load 'fn_zoxide')"
    [ "${output}" = "v1" ]

    _tool zoxide other "${SANDBOX}/other"
    PATH_UNDER_TEST="${SANDBOX}/other:${SHIMS}:/usr/bin:/bin"
    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "other" ]
    [ "$(_runs zoxide)" -eq 2 ]
}

@test "a truncated cache falls back to the live eval and is rewritten" {
    _tool zoxide v1
    _zsh "$(_load 'fn_zoxide')"
    head -n 2 "${CACHE}/zsh/init-zoxide.zsh" >"${SANDBOX}/cut"
    cp "${SANDBOX}/cut" "${CACHE}/zsh/init-zoxide.zsh"

    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "v1" ]
    [ "$(_runs zoxide)" -eq 2 ]
    _zsh "$(_load 'fn_zoxide')"
    [ "${output}" = "v1" ]
    [ "$(_runs zoxide)" -eq 2 ]
}

@test "a stale or foreign cache file is never trusted: the live eval wins" {
    _tool zoxide live
    mkdir -p "${CACHE}/zsh"
    printf '%s\n' "fn_zoxide() { echo stale; }" >"${CACHE}/zsh/init-zoxide.zsh"

    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "live" ]
    [ "$(_runs zoxide)" -eq 1 ]
}

@test "an unwritable cache dir still gives the live init and no noise" {
    _tool zoxide v1
    : >"${SANDBOX}/not-a-dir"
    XDG_CACHE_HOME_UNDER_TEST="${SANDBOX}/not-a-dir"

    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "v1" ]
}

@test "without XDG_CACHE_HOME the init is live and nothing is written" {
    _tool zoxide v1
    ZSH_EXTRA_ENV=(XDG_CACHE_HOME=)

    _zsh "$(_load 'fn_zoxide')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "v1" ]
    [ ! -e "${HOME}/.cache" ]
    [ ! -e "/zsh/init-zoxide.zsh" ]
}

@test "a missing tool is skipped silently and writes no cache" {
    _zsh "$(_load 'print -r -- ok')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "ok" ]
    [ ! -e "${CACHE}/zsh/init-zoxide.zsh" ]
    [ ! -e "${CACHE}/zsh/init-starship.zsh" ]
    [ ! -e "${CACHE}/zsh/init-mise.zsh" ]
}

@test "DOTS_INIT_CACHE=0 turns the cache off and evaluates live every time" {
    _tool zoxide v1
    ZSH_EXTRA_ENV=(DOTS_INIT_CACHE=0)

    _zsh "$(_load 'fn_zoxide')"
    _zsh "$(_load 'fn_zoxide')"

    [ "${output}" = "v1" ]
    [ "$(_runs zoxide)" -eq 2 ]
    [ ! -e "${CACHE}/zsh/init-zoxide.zsh" ]
}

# --- 3. mise: same hooks from the cache, PATH never frozen --------------------

# _mise [line] — a fake mise whose `activate zsh` prints what the real one does
# in a clean environment: two PATH lines that embed the PATH it ran under, the
# hook functions and their registration, plus an optional extra line. It uses
# only shell builtins (the cache generates it under a PATH with no tools on it).
# Anything but `activate zsh` exits 0 silently.
_mise() {
    local extra=${1:-} pathline=${2:-}
    [ -n "${pathline}" ] || pathline='"export PATH='"'"'/mise-shims:$PATH'"'"'"'
    cat >"${SHIMS}/mise" <<EOF
#!/bin/sh
[ "\$1 \$2" = "activate zsh" ] || exit 0
echo run >> "${COUNTS}/mise"
printf '%s\\n' \\
    "export __MISE_ORIG_PATH='\$PATH'" \\
    ${pathline} \\
    'autoload -Uz add-zsh-hook' \\
    '_mise_hook() { :; }' \\
    '_mise_hook_precmd() { :; }' \\
    '_mise_hook_chpwd() { :; }' \\
    'add-zsh-hook precmd _mise_hook_precmd' \\
    'add-zsh-hook chpwd _mise_hook_chpwd' \\
    'fn_mise() { echo mise-live; }' \\
    '${extra}'
EOF
    chmod +x "${SHIMS}/mise"
    touch -t 202001010000 "${SHIMS}/mise"
}

_hooks='print -r -- "precmd:${precmd_functions[(I)_mise_hook_precmd]:-0} chpwd:${chpwd_functions[(I)_mise_hook_chpwd]:-0} fn:${+functions[_mise_hook]}"'

@test "mise: the private precmd hook is still removed and the chpwd hook kept, live and from the cache" {
    _mise

    _zsh "$(_load "${_hooks}")"
    [ "${status}" -eq 0 ]
    [ "${output}" = "precmd:0 chpwd:1 fn:1" ]
    [ -s "${CACHE}/zsh/init-mise.zsh" ]

    _zsh "$(_load "${_hooks}")"
    [ "${status}" -eq 0 ]
    [ "${output}" = "precmd:0 chpwd:1 fn:1" ]
    [ "$(_runs mise)" -eq 1 ]
}

@test "mise: the cache never freezes PATH — the shims dir joins the PATH of the shell that sources it" {
    _mise
    _zsh "$(_load 'print -r -- "$PATH|$__MISE_ORIG_PATH"')"
    [ "${output}" = "/mise-shims:${SHIMS}:/usr/bin:/bin|${SHIMS}:/usr/bin:/bin" ]

    PATH_UNDER_TEST="${SHIMS}:/usr/bin:/bin:/later"
    _zsh "$(_load 'print -r -- "$PATH|$__MISE_ORIG_PATH"')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "/mise-shims:${SHIMS}:/usr/bin:/bin:/later|${SHIMS}:/usr/bin:/bin:/later" ]
    [ "$(_runs mise)" -eq 1 ]
}

@test "mise: a shell that inherits an activated mise evaluates live and caches nothing" {
    _mise 'echo prelude-from-live'
    ZSH_EXTRA_ENV=(MISE_SHELL=zsh)

    _zsh "$(_load 'print -r -- done')"
    _zsh "$(_load 'print -r -- done')"

    [ "$(_runs mise)" -eq 2 ]
    [ ! -e "${CACHE}/zsh/init-mise.zsh" ]
}

@test "mise: an init form it cannot make PATH-independent is evaluated live, not cached" {
    # A PATH line the cache cannot rewrite (double quotes): refuse to freeze it.
    _mise '' '"export PATH=\"/mise-shims:$PATH\""'

    _zsh "$(_load 'fn_mise')"
    _zsh "$(_load 'fn_mise')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "mise-live" ]
    [ ! -e "${CACHE}/zsh/init-mise.zsh" ]
}

@test "mise: the cache is regenerated when the mise binary changes" {
    _mise
    _zsh "$(_load 'fn_mise')"
    [ "$(_runs mise)" -eq 1 ]

    touch -t 202101010000 "${SHIMS}/mise"
    _zsh "$(_load 'fn_mise')"

    [ "${status}" -eq 0 ]
    [ "${output}" = "mise-live" ]
    [ "$(_runs mise)" -eq 2 ]
}
