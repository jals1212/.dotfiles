package tui

// defaultTools returns the tool catalog used by both the interactive TUI and
// the non-interactive install path. Each entry holds display metadata only;
// UI logic lives in the screen renderers, install logic in install_steps.go.
func defaultTools() []Tool {
	return []Tool{
		{Name: "ghostty", Description: "Ghostty terminal (selected theme + Iosevka)", Selected: true, Category: "terminal"},
		{Name: "tmux", Description: "Tmux multiplexer (TPM + Ukiyo)", Selected: true, Category: "tool"},
		{Name: "nvim", Description: "Neovim (LazyVim + selected theme)", Selected: true, Category: "editor"},
		{Name: "oh-my-posh", Description: "Oh My Posh prompt (selected theme)", Selected: true, Category: "shell"},
		{Name: "atuin", Description: "Atuin shell history", Selected: true, Category: "shell"},
		{Name: "zoxide", Description: "Zoxide smart cd", Selected: true, Category: "shell"},
		{Name: "zsh", Description: "ZSH config (zinit + aliases)", Selected: true, Category: "shell"},
	}
}
