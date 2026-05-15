package tui

import "github.com/charmbracelet/lipgloss"

var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

type paletteStyles struct {
	title, subtitle, selected, cursor, normal, dim, done, running, failed, pending lipgloss.Style
}

func getStyles(p Palette) paletteStyles {
	return paletteStyles{
		title:    lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(p.Title)).MarginBottom(1),
		subtitle: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Subtitle)).MarginBottom(1),
		selected: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Selected)).Bold(true),
		cursor:   lipgloss.NewStyle().Foreground(lipgloss.Color(p.Cursor)),
		normal:   lipgloss.NewStyle().Foreground(lipgloss.Color(p.Normal)),
		dim:      lipgloss.NewStyle().Foreground(lipgloss.Color(p.Dim)),
		done:     lipgloss.NewStyle().Foreground(lipgloss.Color(p.Done)),
		running:  lipgloss.NewStyle().Foreground(lipgloss.Color(p.Running)),
		failed:   lipgloss.NewStyle().Foreground(lipgloss.Color(p.Failed)),
		pending:  lipgloss.NewStyle().Foreground(lipgloss.Color(p.Pending)),
	}
}
