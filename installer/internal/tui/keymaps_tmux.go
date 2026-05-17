package tui

// KeymapEntry describes a single key binding.
type KeymapEntry struct {
	Key         string
	Description string
}

// tmuxKeymaps contains the key bindings deployed by this dotfiles setup.
// Prefix is C-a (remapped from the default C-b).
var tmuxKeymaps = []KeymapEntry{
	{Key: "C-a", Description: "Prefix key (remapped from C-b)"},
	{Key: "prefix + |", Description: "Split pane horizontally"},
	{Key: "prefix + -", Description: "Split pane vertically"},
	{Key: "prefix + h/j/k/l", Description: "Navigate panes (vim-style)"},
	{Key: "prefix + H/J/K/L", Description: "Resize pane (vim-style)"},
	{Key: "prefix + r", Description: "Reload tmux config"},
	{Key: "prefix + I", Description: "Install TPM plugins"},
	{Key: "prefix + U", Description: "Update TPM plugins"},
	{Key: "prefix + n", Description: "Next window"},
	{Key: "prefix + p", Description: "Previous window"},
	{Key: "prefix + c", Description: "New window"},
	{Key: "prefix + &", Description: "Kill window"},
	{Key: "prefix + x", Description: "Kill pane"},
	{Key: "prefix + z", Description: "Zoom pane (toggle fullscreen)"},
	{Key: "prefix + [", Description: "Enter copy mode"},
	{Key: "v (copy mode)", Description: "Begin selection"},
	{Key: "y (copy mode)", Description: "Copy selection"},
}

// renderTmuxKeymaps renders the tmux keymap help screen.
func renderTmuxKeymaps(m Model) string {
	return renderKeymapScreen(m, "Tmux Keymaps", tmuxKeymaps)
}
