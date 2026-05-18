package tui

import "strings"

// HelpEntry describes a single key/action pair for the help footer.
type HelpEntry struct {
	Key    string
	Action string
}

// bracketKey wraps multi-key or named-key entries in square brackets.
// Single-character keys and compound-character chords (e.g. "↑/k", "j/k") stay unbracketed.
func bracketKey(key string) string {
	// A chord contains "/" — e.g. "↑/k", "j/k", "<key>/<key>".
	if strings.Contains(key, "/") {
		return key
	}
	// Single rune (e.g. "q", "j", "k") stays unbracketed.
	if len([]rune(key)) == 1 {
		return key
	}
	// Named or multi-char key (Enter, Esc, Space, …) gets brackets.
	return "[" + key + "]"
}

// RenderHelp renders the help footer as "key action • key action …" styled
// with the palette dim italic. The width parameter is retained for API
// stability but no longer triggers centering; the global Padding(1, 2, 0, 2)
// in View() handles the gutter.
func RenderHelp(entries []HelpEntry, p Palette, width int) string {
	_ = width
	s := getStyles(p)
	sep := s.help.Render(" • ")
	parts := make([]string, 0, len(entries))
	for _, e := range entries {
		parts = append(parts, s.help.Render(bracketKey(e.Key)+" "+e.Action))
	}
	return strings.Join(parts, sep)
}
