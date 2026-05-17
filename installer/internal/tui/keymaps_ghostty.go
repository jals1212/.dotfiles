package tui

// ghosttyKeymaps contains the key bindings configured by this dotfiles setup.
var ghosttyKeymaps = []KeymapEntry{
	{Key: "alt+s", Description: "Write screen file and paste (cursor smear reset)"},
	{Key: "cmd+enter", Description: "Toggle fullscreen"},
	{Key: "cmd+d", Description: "New split (right)"},
	{Key: "cmd+shift+d", Description: "New split (bottom)"},
	{Key: "cmd+w", Description: "Close surface"},
	{Key: "cmd+[", Description: "Previous split/tab"},
	{Key: "cmd+]", Description: "Next split/tab"},
	{Key: "cmd+t", Description: "New tab"},
	{Key: "cmd+shift+[", Description: "Previous tab"},
	{Key: "cmd+shift+]", Description: "Next tab"},
	{Key: "cmd+k", Description: "Clear scrollback"},
	{Key: "cmd++", Description: "Increase font size"},
	{Key: "cmd+-", Description: "Decrease font size"},
	{Key: "cmd+0", Description: "Reset font size"},
}

// renderGhosttyKeymaps renders the Ghostty keymap help screen.
func renderGhosttyKeymaps(m Model) string {
	return renderKeymapScreen(m, "Ghostty Keymaps", ghosttyKeymaps)
}
