package tui

// nvimKeymaps contains the key bindings configured by this dotfiles setup.
// Leader key is set to <Space>.
var nvimKeymaps = []KeymapEntry{
	{Key: "<Space>", Description: "Leader key"},
	{Key: "<Space>ff", Description: "Find files (Telescope)"},
	{Key: "<Space>fg", Description: "Live grep (Telescope)"},
	{Key: "<Space>fb", Description: "Buffers (Telescope)"},
	{Key: "<Space>e", Description: "File explorer (Neo-tree)"},
	{Key: "<Space>gg", Description: "LazyGit"},
	{Key: "<Space>bd", Description: "Delete buffer"},
	{Key: "gd", Description: "Go to definition (LSP)"},
	{Key: "gr", Description: "References (LSP)"},
	{Key: "K", Description: "Hover documentation (LSP)"},
	{Key: "<Space>ca", Description: "Code action (LSP)"},
	{Key: "<Space>rn", Description: "Rename symbol (LSP)"},
	{Key: "<C-h/j/k/l>", Description: "Navigate windows"},
	{Key: "<Space>l", Description: "Lazy plugin manager"},
	{Key: "<Space>cm", Description: "Mason (LSP installer)"},
}

// renderNvimKeymaps renders the Neovim keymap help screen.
func renderNvimKeymaps(m Model) string {
	return renderKeymapScreen(m, "Neovim Keymaps", nvimKeymaps)
}
