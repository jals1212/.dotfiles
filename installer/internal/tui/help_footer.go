package tui

import "strings"

// HelpEntry describes a single key/action pair for the help footer.
type HelpEntry struct {
	Key    string
	Action string
}

// RenderHelp renders the help footer as "key action · key action …" styled
// with the palette dim italic. When width > 0 the footer is centered.
func RenderHelp(entries []HelpEntry, p Palette, width int) string {
	s := getStyles(p)
	sep := s.help.Render(" · ")
	parts := make([]string, 0, len(entries))
	for _, e := range entries {
		parts = append(parts, s.help.Render(e.Key+" "+e.Action))
	}
	line := strings.Join(parts, sep)
	if width > 0 {
		return CenterHorizontally(line, width)
	}
	return line
}
