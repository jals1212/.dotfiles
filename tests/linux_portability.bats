#!/usr/bin/env bats
# tests/linux_portability.bats
# Linux portability: the dots work on Debian/Ubuntu and keep
# their macOS behaviour. Every case runs against PATH shims (a fake `uname`,
# batcat/fdfind-only PATHs) in a sandbox HOME; zsh runs with -f so no host
# startup file leaks in.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ZSH_DIR="${REPO_ROOT_REAL}/content/home/.config/zsh"

setup() {
    command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
    ZSH_BIN="$(command -v zsh)"
    SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"  # physical path: zsh resolves symlinks
    export HOME="${SANDBOX}/home"
    SHIMS="${SANDBOX}/shims"
    mkdir -p "${HOME}" "${SHIMS}"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _shim <name> [body] — an executable stub on the shim PATH.
_shim() {
    printf '#!/bin/sh\n%s\n' "${2:-exit 0}" > "${SHIMS}/${1}"
    chmod +x "${SHIMS}/${1}"
}

# _uname <Linux|Darwin> — fake the kernel name for detect_os and the zsh files.
_uname() { _shim uname "echo $1"; }

# _zsh <script> — run <script> in `zsh -f` with only the shims and the base
# system directories on PATH (Homebrew and the real bat/fd stay out).
_zsh() {
    run env -i HOME="${HOME}" PATH="${SHIMS}:/usr/bin:/bin" "${ZSH_BIN}" -f -c "$1"
}

_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1"; echo "output: ${output}"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1"; return 1 ;; esac; return 0; }

# --- 1. bat / fd under their Debian names -------------------------------------

@test "PAGER and MANPAGER use batcat when only batcat exists" {
    _shim batcat
    _zsh "source '${ZSH_DIR}/.zshenv'; print -r -- \"\$PAGER|\$MANPAGER\""

    [ "${status}" -eq 0 ]
    [ "${output}" = "batcat --paging=always|sh -c 'col -bx | batcat -l man -p'" ]
}

@test "aliases call batcat when only batcat exists" {
    _shim batcat
    _zsh "source '${ZSH_DIR}/.zshenv'; source '${ZSH_DIR}/aliases.zsh'
          alias cat; alias fp; alias -s log; alias -s md; alias -s txt; alias bat"

    [ "${status}" -eq 0 ]
    _has "cat=batcat"
    _has "fzf --preview=\"batcat --theme=dots --color=always {}\""
    _has "log=batcat"
    _has "md=batcat"
    _has "txt=batcat"
    _has "bat=batcat"
}

@test "fzf commands and previews use fdfind and batcat when only those exist" {
    _shim batcat
    _shim fdfind
    _zsh "source '${ZSH_DIR}/.zshenv'; source '${REPO_ROOT_REAL}/content/home/.config/fzf/config.zsh'
          print -r -- \"\$FZF_DEFAULT_COMMAND\"; print -r -- \"\$FZF_ALT_C_COMMAND\"; print -r -- \"\$FZF_CTRL_T_OPTS\""

    [ "${status}" -eq 0 ]
    _has "fdfind --type f --hidden"
    _has "fdfind --type d --hidden"
    _has "--preview 'batcat --theme=dots"
}

@test "the find abbreviation expands to fdfind when only fdfind exists" {
    _shim fdfind
    _zsh "abbr() { print -r -- \"abbr \$*\"; }
          source '${ZSH_DIR}/.zshenv'; source '${ZSH_DIR}/abbr.zsh'"

    [ "${status}" -eq 0 ]
    _has "abbr -S --quieter --force find=fdfind"
}

@test "bat and fd keep their plain names when they exist, even next to batcat/fdfind" {
    _shim bat
    _shim batcat
    _shim fd
    _shim fdfind
    _zsh "source '${ZSH_DIR}/.zshenv'; source '${ZSH_DIR}/aliases.zsh'
          source '${REPO_ROOT_REAL}/content/home/.config/fzf/config.zsh'
          print -r -- \"\$PAGER|\$MANPAGER|\$FZF_DEFAULT_COMMAND\"; alias cat; alias fp; alias -s log
          print -r -- \"bat-alias:\${+aliases[bat]} fd-alias:\${+aliases[fd]}\""

    [ "${status}" -eq 0 ]
    _has "bat --paging=always|sh -c 'col -bx | bat -l man -p'|fd --type f --hidden"
    _has "cat=bat"
    _has "fzf --preview=\"bat --theme=dots --color=always {}\""
    _has "log=bat"
    _has "bat-alias:0 fd-alias:0"
    _lacks "batcat"
    _lacks "fdfind"
}

# --- 2. macOS-only functions --------------------------------------------------

@test "cdf and moshi-pair are not defined on Linux" {
    _uname Linux
    _zsh "source '${ZSH_DIR}/functions.zsh'
          print -r -- \"cdf:\${+functions[cdf]} moshi-pair:\${+functions[moshi-pair]}\""

    [ "${status}" -eq 0 ]
    _has "cdf:0 moshi-pair:0"
}

@test "cdf and moshi-pair stay defined on macOS" {
    _uname Darwin
    _zsh "source '${ZSH_DIR}/functions.zsh'
          print -r -- \"cdf:\${+functions[cdf]} moshi-pair:\${+functions[moshi-pair]}\""

    [ "${status}" -eq 0 ]
    _has "cdf:1 moshi-pair:1"
}

@test "moshi-pair on macOS still refuses to pair without the hardening script" {
    _uname Darwin
    _zsh "source '${ZSH_DIR}/functions.zsh'; moshi-pair"

    [ "${status}" -eq 1 ]
    _has "moshi-pair: missing or non-executable ${HOME}/.config/remote-agents/harden-authorized-keys.sh"
    _has "moshi-pair: refusing to pair without the hardening step"
}

# --- 3. the dots() wrapper finds the repo wherever it is cloned ---------------

# _fake_clone <dir> — a repo layout with a stub dots script and a copy of
# functions.zsh, deployed into $HOME/.config/zsh as a symlink (as dotbot does).
_fake_clone() {
    mkdir -p "$1/content/home/.config/zsh" "${HOME}/.config/zsh"
    cp "${ZSH_DIR}/functions.zsh" "$1/content/home/.config/zsh/functions.zsh"
    printf '#!/bin/sh\necho "dots from $0: $*"\nexit 3\n' > "$1/dots"
    chmod +x "$1/dots"
    ln -s "$1/content/home/.config/zsh/functions.zsh" "${HOME}/.config/zsh/functions.zsh"
}

@test "dots runs the script of the repo the zsh files are linked from, not ~/.dotfiles" {
    _fake_clone "${SANDBOX}/elsewhere/clone"
    _uname Linux
    _zsh "source '${HOME}/.config/zsh/functions.zsh'; dots update --yes"

    [ "${status}" -eq 3 ]
    _has "dots from ${SANDBOX}/elsewhere/clone/dots: update --yes"
}

@test "DOTS_REPO overrides the repo the dots wrapper runs" {
    _fake_clone "${SANDBOX}/elsewhere/clone"
    mkdir -p "${SANDBOX}/chosen"
    printf '#!/bin/sh\necho "chosen: $*"\n' > "${SANDBOX}/chosen/dots"
    chmod +x "${SANDBOX}/chosen/dots"
    _uname Linux
    _zsh "DOTS_REPO='${SANDBOX}/chosen'; source '${HOME}/.config/zsh/functions.zsh'; dots doctor"

    [ "${status}" -eq 0 ]
    _has "chosen: doctor"
}

@test "dots still runs ~/.dotfiles/dots when functions.zsh is not linked from a repo" {
    mkdir -p "${HOME}/.dotfiles" "${SANDBOX}/loose"
    printf '#!/bin/sh\necho "legacy: $*"\nexit 4\n' > "${HOME}/.dotfiles/dots"
    chmod +x "${HOME}/.dotfiles/dots"
    cp "${ZSH_DIR}/functions.zsh" "${SANDBOX}/loose/functions.zsh"
    _uname Linux
    _zsh "source '${SANDBOX}/loose/functions.zsh'; dots theme"

    [ "${status}" -eq 4 ]
    _has "legacy: theme"
}

@test "dots reports a clear error when no repo can be found" {
    mkdir -p "${SANDBOX}/loose"
    cp "${ZSH_DIR}/functions.zsh" "${SANDBOX}/loose/functions.zsh"
    _uname Linux
    _zsh "source '${SANDBOX}/loose/functions.zsh'; dots theme"

    [ "${status}" -eq 1 ]
    _has "dots: repo not found"
    _has "DOTS_REPO"
}

@test "the dotfiles alias opens the resolved repo" {
    _fake_clone "${SANDBOX}/elsewhere/clone"
    _uname Linux
    _zsh "source '${ZSH_DIR}/aliases.zsh'; source '${HOME}/.config/zsh/functions.zsh'
          alias dotfiles; print -r -- \"\$DOTS_REPO\""

    [ "${status}" -eq 0 ]
    _has "${SANDBOX}/elsewhere/clone"
}

# --- 4. doctor skips the macOS-only checks on Linux ---------------------------

# _doctor <script> — run a script with the doctor libs sourced.
_doctor() {
    run env -i HOME="${HOME}" PATH="${SHIMS}:/usr/bin:/bin" NO_COLOR=1 REPO_ROOT="${REPO_ROOT_REAL}" \
        sh -c ". '${REPO_ROOT_REAL}/src/lib/log.sh'; . '${REPO_ROOT_REAL}/src/lib/doctor.sh'; $1"
}

@test "doctor skips the OrbStack and Docker checks on Linux" {
    _uname Linux
    _doctor 'check_orbstack; echo "rc=$?"; check_docker; echo "rc=$?"; check_docker_buildx; echo "rc=$?"; check_docker_compose; echo "rc=$?"'

    [ "${status}" -eq 0 ]
    _has "[SKIP] OrbStack CLI: macOS only"
    _has "[SKIP] Docker CLI: macOS only"
    _has "[SKIP] Docker Buildx: macOS only"
    _has "[SKIP] Docker Compose: macOS only"
    _lacks "[FAIL]"
    [ "$(printf '%s\n' "${output}" | grep -c '^rc=0$')" -eq 4 ]
}

@test "doctor skips the ghostty checks on Linux" {
    _uname Linux
    _doctor 'check_ghostty_link; echo "rc=$?"; check_ghostty_theme_link; echo "rc=$?"; check_ghostty_theme_marker; echo "rc=$?"'

    [ "${status}" -eq 0 ]
    _has "[SKIP] ghostty config: macOS only"
    _has "[SKIP] ghostty theme: macOS only"
    _has "[SKIP] ghostty theme = dots: macOS only"
    _lacks "[FAIL]"
    [ "$(printf '%s\n' "${output}" | grep -c '^rc=0$')" -eq 3 ]
}

@test "doctor still fails the same checks on macOS when the tools are missing" {
    _uname Darwin
    _doctor 'check_orbstack; echo "rc=$?"; check_docker; echo "rc=$?"; check_ghostty_link; echo "rc=$?"; check_ghostty_theme_marker; echo "rc=$?"'

    [ "${status}" -eq 0 ]
    _has "[FAIL] OrbStack CLI present: command not found: orb"
    _has "[FAIL] Docker CLI present: command not found: docker"
    _has "[FAIL] ghostty config: missing: ${HOME}/.config/ghostty/config"
    _has "[FAIL] ghostty theme = dots: unreadable: ${HOME}/.config/ghostty/config"
    _lacks "[SKIP]"
    [ "$(printf '%s\n' "${output}" | grep -c '^rc=1$')" -eq 4 ]
}

@test "dots doctor exits 0 on Linux with only macOS-only checks missing" {
    REPO="${SANDBOX}/repo"
    mkdir -p "${REPO}/vendor/dotbot/bin"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO}/src"
    cp "${REPO_ROOT_REAL}/dots" "${REPO}/dots"
    printf '#!/bin/sh\nexit 0\n' > "${REPO}/vendor/dotbot/bin/dotbot"
    chmod +x "${REPO}/vendor/dotbot/bin/dotbot"
    printf '%s\n' \
        'DOCTOR_CHECKS="check_dotbot_submodule check_orbstack check_docker check_ghostty_link check_ghostty_theme_marker"' \
        'export DOCTOR_CHECKS' >> "${REPO}/src/lib/doctor.sh"
    printf '{}\n' > "${REPO}/manifest.json"
    _uname Linux

    run env PATH="${SHIMS}:${PATH}" sh "${REPO}/dots" doctor
    echo "${output}"

    [ "${status}" -eq 0 ]
    _has "[PASS] dotbot submodule"
    _has "[SKIP] OrbStack CLI: macOS only"
    _has "5/5 checks passed"
    _lacks "[FAIL]"
}

# --- 5. _doc_macos_only fails closed: only a positive Linux skips ---------------

# _doctor_os <setup> <check> — doctor.sh sourced with no REPO_ROOT, so it does
# not load detect.sh itself; <setup> may define or break detect_os.
_doctor_os() {
    run env -i HOME="${HOME}" PATH="${SHIMS}:/usr/bin:/bin" NO_COLOR=1 \
        sh -c ". '${REPO_ROOT_REAL}/src/lib/log.sh'; . '${REPO_ROOT_REAL}/src/lib/doctor.sh'; $1; $2; echo \"rc=\$?\""
}

@test "doctor runs the macOS-only check when detect_os is not defined" {
    _doctor_os 'command -v detect_os >/dev/null 2>&1 && unset -f detect_os' 'check_orbstack'

    [ "${status}" -eq 0 ]
    _has "[FAIL] OrbStack CLI present: command not found: orb"
    _lacks "[SKIP]"
    _has "rc=1"
}

@test "doctor runs the macOS-only check when detect_os fails" {
    _doctor_os 'detect_os() { return 1; }' 'check_orbstack'

    [ "${status}" -eq 0 ]
    _has "[FAIL] OrbStack CLI present: command not found: orb"
    _lacks "[SKIP]"
    _has "rc=1"
}

@test "doctor runs the macOS-only check when detect_os says unknown or prints nothing" {
    _doctor_os 'detect_os() { printf unknown; }' 'check_orbstack'
    [ "${status}" -eq 0 ]
    _has "[FAIL] OrbStack CLI present: command not found: orb"
    _lacks "[SKIP]"

    _doctor_os 'detect_os() { :; }' 'check_ghostty_theme_marker'
    [ "${status}" -eq 0 ]
    _has "[FAIL] ghostty theme = dots"
    _lacks "[SKIP]"
}

@test "doctor skips the macOS-only check only when detect_os says linux" {
    _doctor_os 'detect_os() { printf linux; }' 'check_orbstack'

    [ "${status}" -eq 0 ]
    _has "[SKIP] OrbStack CLI: macOS only"
    _lacks "[FAIL]"
    _has "rc=0"
}

