package tui

// zshKeymaps contains the key bindings and shell aliases configured by this
// dotfiles setup via .zalias and .zkey.
var zshKeymaps = []KeymapEntry{
	{Key: "ctrl+r", Description: "Atuin history search (interactive)"},
	{Key: "ctrl+t", Description: "fzf file picker"},
	{Key: "ctrl+]", Description: "fzf directory picker (zoxide)"},
	{Key: "z <query>", Description: "Smart cd via zoxide"},
	{Key: "zi", Description: "Interactive zoxide jump"},
	{Key: "ll", Description: "eza long list with git"},
	{Key: "la", Description: "eza long list all files"},
	{Key: "lt", Description: "eza tree view"},
	{Key: "gst", Description: "git status"},
	{Key: "gco", Description: "git checkout"},
	{Key: "glog", Description: "git log --oneline --graph"},
	{Key: "vim / vi", Description: "Opens nvim"},
	{Key: "cat", Description: "bat (syntax-highlighted cat)"},
}

// renderZshKeymaps renders the Zsh keymap and alias help screen.
func renderZshKeymaps(m Model) string {
	return renderKeymapScreen(m, "Zsh Keymaps & Aliases", zshKeymaps)
}
