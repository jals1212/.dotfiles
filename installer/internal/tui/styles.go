package tui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

type paletteStyles struct {
	title, subtitle, selected, cursor, normal, dim, done, running, failed, pending lipgloss.Style
	box                                                                             lipgloss.Style
	stepActive, stepDone, stepPending                                               lipgloss.Style
	help, key                                                                       lipgloss.Style
	success, error, warning, info                                                   lipgloss.Style
	selectedItem, unselectedItem                                                    lipgloss.Style
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

		box: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(p.Dim)).
			Padding(1, 2),

		stepDone:    lipgloss.NewStyle().Foreground(lipgloss.Color(p.Done)),
		stepActive:  lipgloss.NewStyle().Foreground(lipgloss.Color(p.Selected)).Bold(true),
		stepPending: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Dim)),

		help: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Dim)).Italic(true).MarginTop(1),
		key:  lipgloss.NewStyle().Foreground(lipgloss.Color(p.Selected)).Bold(true),

		success: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Done)),
		error:   lipgloss.NewStyle().Foreground(lipgloss.Color(p.Failed)),
		warning: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Running)),
		info:    lipgloss.NewStyle().Foreground(lipgloss.Color(p.Subtitle)),

		selectedItem:   lipgloss.NewStyle().Foreground(lipgloss.Color(p.Selected)).Bold(true).PaddingLeft(2),
		unselectedItem: lipgloss.NewStyle().Foreground(lipgloss.Color(p.Normal)).PaddingLeft(4),
	}
}

// SubcommandStyles holds palette-aware lipgloss styles for non-interactive subcommand output.
type SubcommandStyles struct {
	Title    lipgloss.Style
	Subtitle lipgloss.Style
	Normal   lipgloss.Style
	Dim      lipgloss.Style
	Done     lipgloss.Style
	Failed   lipgloss.Style
}

// SubcommandStylesFor returns palette-aware styles for use by non-interactive subcommands
// (e.g. dots doctor, dots update). These are a subset of the full paletteStyles,
// copied into an exported struct so cmd/dots can import them without depending on
// the unexported paletteStyles type.
func SubcommandStylesFor(p Palette) SubcommandStyles {
	s := getStyles(p)
	return SubcommandStyles{
		Title:    s.title,
		Subtitle: s.subtitle,
		Normal:   s.normal,
		Dim:      s.dim,
		Done:     s.done,
		Failed:   s.failed,
	}
}

// CenterHorizontally centers text within width using lipgloss alignment.
// Returns text unchanged when width is zero.
func CenterHorizontally(text string, width int) string {
	if width == 0 {
		return text
	}
	return lipgloss.NewStyle().Width(width).Align(lipgloss.Center).Render(text)
}

// CenterVertically adds top padding to vertically center text within height.
// Returns text unchanged when height is zero.
func CenterVertically(text string, height int) string {
	if height == 0 {
		return text
	}
	lines := strings.Count(text, "\n") + 1
	padTop := (height - lines) / 2
	if padTop <= 0 {
		return text
	}
	return strings.Repeat("\n", padTop) + text
}

// CenterBoth places text at the center of a width×height region using lipgloss.Place.
// Returns text unchanged when width or height is zero.
func CenterBoth(text string, width, height int) string {
	if width == 0 || height == 0 {
		return text
	}
	return lipgloss.Place(width, height, lipgloss.Center, lipgloss.Center, text)
}
