#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
SKIPPED=0
INSTALL_OUTPUT=""

log_test() { printf "${YELLOW}[TEST]${NC} %s\n" "$1"; }
log_pass() {
    printf "${GREEN}[PASS]${NC} %s\n" "$1"
    PASSED=$((PASSED + 1))
}
log_skip() {
    printf "${BLUE}[SKIP]${NC} %s\n" "$1"
    SKIPPED=$((SKIPPED + 1))
}
log_fail() {
    printf "${RED}[FAIL]${NC} %s\n" "$1"
    exit 1
}

assert_file() {
    local file="$1"
    [ -f "$file" ] || log_fail "$file not found"
    log_pass "$file exists"
}

assert_dir() {
    local dir="$1"
    [ -d "$dir" ] || log_fail "$dir not found"
    log_pass "$dir exists"
}

assert_contains() {
    local file="$1"
    local text="$2"
    grep -Fq "$text" "$file" || log_fail "$file missing: $text"
    log_pass "$file contains expected text"
}

assert_not_in_output() {
    local text="$1"
    if printf '%s\n' "$INSTALL_OUTPUT" | grep -Fq "$text"; then
        printf '%s\n' "$INSTALL_OUTPUT"
        log_fail "install output unexpectedly contained: $text"
    fi
    log_pass "install output suppresses: $text"
}

assert_marker_once() {
    local file="$1"
    local marker="$2"
    local count
    count=$(grep -F "$marker" "$file" | wc -l | tr -d ' ')
    [ "$count" = "1" ] || log_fail "$file marker $marker count=$count, want 1"
    log_pass "$file marker $marker is single"
}

setup_fake_bat() {
    mkdir -p "$HOME/bin"
    cat > "$HOME/bin/bat" <<'EOF'
#!/bin/sh
if [ "$1" = "cache" ] && [ "$2" = "--build" ]; then
  count_file="$HOME/bat-cache-count"
  count=0
  if [ -f "$count_file" ]; then
    count=$(cat "$count_file")
  fi
  count=$((count + 1))
  printf '%s\n' "$count" > "$count_file"
  echo "Writing theme set to /tmp/bat/themes.bin ... okay"
  echo "Writing syntax set to /tmp/bat/syntaxes.bin ... okay"
  exit 0
fi
exit 0
EOF
    chmod +x "$HOME/bin/bat"
    export PATH="$HOME/bin:$PATH"
}

test_binary_runs() {
    log_test "Binary executes help"
    if dots help >/dev/null 2>&1; then
        log_pass "dots help executes"
    else
        log_fail "dots help failed"
    fi

    if dots update --help >/tmp/dots-update-help.log 2>&1 && grep -Fq "dots update" /tmp/dots-update-help.log; then
        log_pass "dots update --help is side-effect free"
    else
        cat /tmp/dots-update-help.log
        log_fail "dots update --help failed"
    fi

    if dots uninstall --help >/tmp/dots-uninstall-help.log 2>&1 && grep -Fq "dots uninstall" /tmp/dots-uninstall-help.log; then
        log_pass "dots uninstall --help is side-effect free"
    else
        cat /tmp/dots-uninstall-help.log
        log_fail "dots uninstall --help failed"
    fi

    if dots doctor --help >/tmp/dots-doctor-help.log 2>&1 && grep -Fq "dots doctor" /tmp/dots-doctor-help.log; then
        log_pass "dots doctor --help is side-effect free"
    else
        cat /tmp/dots-doctor-help.log
        log_fail "dots doctor --help failed"
    fi
}

test_non_interactive_install() {
    log_test "Non-interactive install deploys configs"

    setup_fake_bat
    mkdir -p "$HOME/.config/nvim"
    printf '%s\n' "original zsh before dots install" > "$HOME/.zshrc"
    printf '%s\n' "original nvim before dots install" > "$HOME/.config/nvim/init.lua"

    if INSTALL_OUTPUT="$(DOTS_VERBOSE=1 DOTS_THEME=kanagawa DOTS_FLAVOR=dragon dots install --yes 2>&1)"; then
        log_pass "install completed"
    else
        printf '%s\n' "$INSTALL_OUTPUT"
        log_fail "install failed"
    fi

    assert_not_in_output "Writing theme set"
    assert_not_in_output "Writing syntax set"
}

test_deployed_files() {
    log_test "Required config files are deployed"

    assert_file "$HOME/.zshrc"
    assert_file "$HOME/.zprofile"
    assert_file "$HOME/.zalias"
    assert_dir "$HOME/.config"
    assert_file "$HOME/.config/oh-my-posh/config.json"
    assert_file "$HOME/.config/nvim/init.lua"
    assert_file "$HOME/.config/nvim/lua/config/lazy.lua"
    assert_file "$HOME/.config/nvim/lua/config/nodejs.lua"
    assert_file "$HOME/.config/nvim/lua/plugins/opencode.lua"
    assert_file "$HOME/.config/tmux/tmux.conf"
    assert_file "$HOME/.config/ghostty/config"
    assert_file "$HOME/.config/aerospace/aerospace.toml"
}

test_prompt_and_theme_outputs() {
    log_test "Prompt and theme outputs are valid"

    assert_contains "$HOME/.zshrc" "oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json"
    python3 -m json.tool "$HOME/.config/oh-my-posh/config.json" >/dev/null
    log_pass "Oh My Posh config is valid JSON"

    assert_file "$HOME/.config/bat/themes/Kanagawa-dragon.tmTheme"
    assert_contains "$HOME/.zshrc" 'export BAT_THEME="Kanagawa Dragon"'
}

test_nvim_config_smoke() {
    log_test "Neovim deployed config smoke"

    assert_contains "$HOME/.config/nvim/init.lua" 'require("config.lazy")'
    assert_contains "$HOME/.config/nvim/init.lua" 'require("config.nodejs").setup({ silent = true })'
    assert_contains "$HOME/.config/nvim/lua/config/lazy.lua" '"LazyVim/LazyVim"'
    assert_contains "$HOME/.config/nvim/lua/plugins/opencode.lua" '"NickvanDyke/opencode.nvim"'

    local lazy_path="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
    if command -v nvim >/dev/null 2>&1 && [ -d "$lazy_path" ]; then
        DOTS_NVIM_NO_INSTALL=1 nvim --headless -c 'quitall' >/dev/null 2>&1
        log_pass "nvim headless startup succeeded"
    else
        log_skip "nvim headless smoke skipped because nvim/lazy.nvim is unavailable"
    fi
}

test_terminal_window_manager_configs() {
    log_test "Terminal and window manager configs follow shortcut policy"

    assert_contains "$HOME/.config/tmux/tmux.conf" "set -g prefix C-a"
    assert_contains "$HOME/.config/ghostty/config" "keybind = alt+s=write_screen_file:paste"

    local shader_dir="$HOME/.config/ghostty/shaders"
    assert_file "$shader_dir/cursor_smear.glsl"
    local shader_count
    shader_count=$(find "$shader_dir" -type f | wc -l | tr -d ' ')
    [ "$shader_count" = "1" ] || log_fail "Ghostty shader count=$shader_count, want 1"
    log_pass "Ghostty keeps only cursor smear shader"

    local aerospace="$HOME/.config/aerospace/aerospace.toml"
    if grep -Eq '^[[:space:]]*alt(-shift)?-[a-z0-9]' "$aerospace"; then
        log_fail "AeroSpace has global alt bindings"
    fi
    assert_contains "$aerospace" "ctrl-alt-minus = 'resize smart -50'"
    assert_contains "$aerospace" "ctrl-alt-equal = 'resize smart +50'"
}

test_update_idempotency() {
    log_test "Update is idempotent for generated marker blocks"

    if DOTS_THEME=kanagawa DOTS_FLAVOR=dragon dots update >/tmp/dots-update.log 2>&1; then
        log_pass "dots update completed"
    else
        cat /tmp/dots-update.log
        log_fail "dots update failed"
    fi

    assert_marker_once "$HOME/.zshrc" "# dots:bat-theme begin"
    [ -f "$HOME/.config/ghostty/themes/dots" ] || log_fail "ghostty themes/dots file missing"
    [ -f "$HOME/.config/fzf/theme.sh" ] || log_fail "fzf theme.sh file missing"
    [ -f "$HOME/.config/eza/colors.sh" ] || log_fail "eza colors.sh file missing"
    [ -f "$HOME/.config/atuin/themes/dots.toml" ] || log_fail "atuin themes/dots.toml file missing"
    grep -q 'name = "dots"' "$HOME/.config/atuin/config.toml" || log_fail "atuin config missing name = \"dots\""

    local bat_cache_count
    bat_cache_count=$(cat "$HOME/bat-cache-count")
    [ "$bat_cache_count" = "1" ] || log_fail "bat cache build count=$bat_cache_count, want 1 after unchanged update"
    log_pass "unchanged update skips bat cache rebuild"
}

test_reload_noop_when_current() {
    log_test "Reload skips when source is current"

    local output
    if output="$(DOTS_THEME=kanagawa DOTS_FLAVOR=dragon dots reload 2>&1)"; then
        log_pass "dots reload completed"
    else
        printf '%s\n' "$output"
        log_fail "dots reload failed"
    fi

    if printf '%s\n' "$output" | grep -Fq "Configs already current"; then
        log_pass "dots reload reports configs already current"
    else
        printf '%s\n' "$output"
        log_fail "dots reload did not report already current"
    fi
}

test_doctor() {
    log_test "Doctor validates deployed configs"

    local output
    if output="$(dots doctor 2>&1)"; then
        log_pass "dots doctor completed"
    else
        printf '%s\n' "$output"
        log_fail "dots doctor failed"
    fi

    if printf '%s\n' "$output" | grep -Fq "All doctor checks passed"; then
        log_pass "dots doctor reports healthy configs"
    else
        printf '%s\n' "$output"
        log_fail "dots doctor did not report healthy configs"
    fi
}

test_restore_latest_backup() {
    log_test "Restore latest backup"

    if dots restore --latest >/tmp/dots-restore.log 2>&1; then
        log_pass "dots restore --latest completed"
    else
        cat /tmp/dots-restore.log
        log_fail "dots restore --latest failed"
    fi

    assert_contains "$HOME/.zshrc" "original zsh before dots install"
    assert_contains "$HOME/.config/nvim/init.lua" "original nvim before dots install"
}

test_binary_runs
test_non_interactive_install
test_deployed_files
test_prompt_and_theme_outputs
test_nvim_config_smoke
test_terminal_window_manager_configs
test_update_idempotency
test_reload_noop_when_current
test_doctor
test_restore_latest_backup

printf "\n${GREEN}All E2E checks passed${NC} (${PASSED} passed, ${SKIPPED} skipped)\n"
