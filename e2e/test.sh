#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check_file() {
    local target="$1"
    local description="$2"

    if [ -f "$target" ] || [ -d "$target" ]; then
        echo -e "${GREEN}✓${NC} $description (${target})"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗${NC} $description — MISSING (${target})"
        FAIL=$((FAIL + 1))
    fi
}

check_file_contains() {
    local target="$1"
    local pattern="$2"
    local description="$3"

    if [ -f "$target" ] || [ -L "$target" ]; then
        if grep -q "$pattern" "$target" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $description"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗${NC} $description — pattern not found"
            FAIL=$((FAIL + 1))
        fi
    else
        echo -e "${RED}✗${NC} $description — file missing"
        FAIL=$((FAIL + 1))
    fi
}

echo "════════════════════════════════════════"
echo "  dots — E2E Deployment Validation"
echo "════════════════════════════════════════"
echo ""

echo "Running dots install --yes..."
./dots install --yes || {
    echo -e "${RED}dots install --yes failed!${NC}"
    exit 1
}
echo ""

echo "Checking deployed configs..."
echo ""

check_file "$HOME/.config/ghostty/config" "Ghostty config"
check_file_contains "$HOME/.config/ghostty/config" "IosevkaTerm" "Ghostty font setting"
check_file_contains "$HOME/.config/ghostty/config" "1e1e2e" "Ghostty Catppuccin background"

check_file "$HOME/.config/tmux/tmux.conf" "Tmux config"
check_file_contains "$HOME/.config/tmux/tmux.conf" "catppuccin/tmux" "Tmux catppuccin plugin"
check_file_contains "$HOME/.config/tmux/tmux.conf" "prefix C-Space" "Tmux prefix key"
check_file_contains "$HOME/.config/tmux/tmux.conf" "test ! -d ~/.config/tmux/plugins/tpm" "TPM auto-install snippet"

check_file "$HOME/.config/nvim/init.lua" "Neovim init.lua"
check_file_contains "$HOME/.config/nvim/init.lua" "lazy" "LazyVim bootstrap"
check_file_contains "$HOME/.config/nvim/lua/plugins/colorschemes.lua" "catppuccin" "Nvim catppuccin theme"

check_file "$HOME/.config/starship.toml" "Starship config"
check_file_contains "$HOME/.config/starship.toml" "catppuccin_mocha" "Starship Catppuccin palette"
check_file_contains "$HOME/.config/starship.toml" "mauve" "Starship mauve color"

check_file "$HOME/.config/atuin/config.toml" "Atuin config"
check_file_contains "$HOME/.config/atuin/config.toml" "catppuccin-mocha" "Atuin Catppuccin theme"
check_file_contains "$HOME/.config/atuin/config.toml" "auto_sync = false" "Atuin local-only mode"

check_file "$HOME/.zshrc" "ZSH rc"
check_file "$HOME/.zprofile" "ZSH profile"
check_file "$HOME/.zalias" "ZSH aliases"
check_file "$HOME/.zfunc" "ZSH functions"
check_file "$HOME/.zkey" "ZSH keybindings"
check_file_contains "$HOME/.zshrc" "starship" "Starship init in zshrc"
check_file_contains "$HOME/.zshrc" "atuin" "Atuin init in zshrc"
check_file_contains "$HOME/.zshrc" "zoxide" "Zoxide init in zshrc"
check_file_contains "$HOME/.zalias" "eza" "eza alias"
check_file_contains "$HOME/.zalias" "git='hub'" "hub alias"
check_file_contains "$HOME/.zshrc" "zsh-autosuggestions" "zsh autosuggestions plugin"
check_file_contains "$HOME/.zshrc" "zsh-syntax-highlighting" "zsh syntax highlighting plugin"

check_file_contains "manifest.json" "deployed_at" "Deploy manifest exists"

echo ""
echo "════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0