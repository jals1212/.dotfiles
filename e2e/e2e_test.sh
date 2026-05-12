#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() { printf "${YELLOW}[TEST]${NC} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; }
log_fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; exit 1; }

test_non_interactive_install() {
    log_test "Non-interactive install"
    
    if DOTS_VERBOSE=1 dots install --yes 2>&1; then
        log_pass "Install completed"
    else
        log_fail "Install failed"
    fi
    
    if [ -d "$HOME/.config" ]; then
        log_pass "~/.config exists"
    else
        log_fail "~/.config not found"
    fi
}

test_config_files() {
    log_test "Config files deployed"
    
    for f in .zshrc .zalias; do
        if [ -f "$HOME/$f" ]; then
            log_pass "$f deployed"
        else
            log_fail "$f not found"
        fi
    done
}

test_non_interactive_install
test_config_files

log_pass "All tests passed!"
