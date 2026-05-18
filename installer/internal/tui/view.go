package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// View implements the tea.Model interface by routing to the per-screen renderer.
func (m Model) View() string {
	out := renderView(m)
	return lipgloss.NewStyle().Padding(1, 2, 0, 2).Render(out)
}

func renderView(m Model) string {
	switch m.Screen {
	case ScreenWelcome:
		return renderWelcome(m)
	case ScreenThemeFlavor:
		return renderThemeFlavor(m)
	case ScreenToolSelect:
		return renderToolSelect(m)
	case ScreenBackupConfirm:
		return renderBackupConfirm(m)
	case ScreenInstalling:
		return renderInstalling(m)
	case ScreenSummary:
		return renderSummary(m)
	case ScreenError:
		return renderError(m)
	default:
		return ""
	}
}

// renderChrome composes the full layered chrome around content.
// stepLine may be empty for off-funnel screens.
// No box is applied; header and stepLine are joined with newlines only.
func renderChrome(m Model, stepLine, content, footer string) string {
	b := strings.Builder{}
	if stepLine != "" {
		b.WriteString(stepLine)
		b.WriteString("\n\n")
	}
	b.WriteString(content)
	b.WriteString("\n")
	b.WriteString(footer)
	return b.String()
}

func renderWelcome(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)

	var bodyB strings.Builder
	s := getStyles(m.Palette)
	bodyB.WriteString(s.subtitle.Render(fmt.Sprintf("Detected: %s (%s)", m.SystemInfo.OSName, m.SystemInfo.Arch)))
	bodyB.WriteString("\n\n")
	bodyB.WriteString(s.dim.Render("Press enter to continue..."))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "continue"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return header + "\n" + bodyB.String() + "\n" + footer
}

// renderThemeFlavor renders the merged theme+flavor+preview screen.
// Layout: step indicator → title → two-column list (Themes | Flavors) →
// preview block → help footer. Space commits selection; Enter advances.
func renderThemeFlavor(m Model) string {
	stepLine := RenderSteps(installFunnelSteps(), currentStepIndex(ScreenThemeFlavor), m.Palette, m.Width)
	s := getStyles(m.Palette)

	themes := defaultThemes()

	// Determine hovered theme/flavor for live preview (no state mutation).
	hoveredTheme := m.SelectedTheme
	hoveredFlavor := m.SelectedFlavor
	if m.Panel == 0 && m.Cursor < len(themes) {
		hoveredTheme = themes[m.Cursor].Name
		hoveredFlavor = defaultFlavorForTheme(hoveredTheme)
		// If the hovered theme matches the selected theme, use the committed flavor.
		if hoveredTheme == m.SelectedTheme {
			hoveredFlavor = m.SelectedFlavor
		}
	} else if m.Panel == 1 {
		hoveredTheme = m.SelectedTheme
		flavors := defaultFlavorsForTheme(hoveredTheme)
		if m.Cursor < len(flavors) {
			hoveredFlavor = flavors[m.Cursor]
		}
	}

	// Build theme rows (left column, width 28).
	// Row format: <cursor(2)><marker(2)><label>  padded to colWidth visible cells.
	// We use s.selected (bold, no padding) and s.normal (no padding) for labels
	// to avoid lipgloss PaddingLeft interfering with column alignment.
	const colWidth = 28
	themeRows := make([]string, len(themes))
	for i, th := range themes {
		cursorStr := "  "
		if m.Panel == 0 && i == m.Cursor {
			cursorStr = "▸ "
		}
		markerPlain := "  "
		var markerStyled string
		if th.Name == m.SelectedTheme {
			markerPlain = "● "
			markerStyled = s.selected.Render("● ")
		} else {
			markerStyled = "  "
		}
		label := th.DisplayName
		var styledLabel string
		if m.Panel == 0 && i == m.Cursor {
			styledLabel = s.selected.Render(label)
		} else {
			styledLabel = s.normal.Render(label)
		}
		row := cursorStr + markerStyled + styledLabel
		// Pad row to colWidth visible cells so the right column aligns.
		plainRow := cursorStr + markerPlain + label
		if pad := colWidth - len([]rune(plainRow)); pad > 0 {
			row = row + strings.Repeat(" ", pad)
		}
		themeRows[i] = row
	}

	// Build flavor rows (right column).
	var flavorRows []string
	if m.SelectedTheme != "" {
		flavors := defaultFlavorsForTheme(m.SelectedTheme)
		flavorRows = make([]string, len(flavors))
		for i, fl := range flavors {
			cursorStr := "  "
			if m.Panel == 1 && i == m.Cursor {
				cursorStr = "▸ "
			}
			var markerStyled string
			if fl == m.SelectedFlavor {
				markerStyled = s.selected.Render("● ")
			} else {
				markerStyled = "  "
			}
			var styledLabel string
			if m.Panel == 1 && i == m.Cursor {
				styledLabel = s.selected.Render(fl)
			} else {
				styledLabel = s.normal.Render(fl)
			}
			flavorRows[i] = cursorStr + markerStyled + styledLabel
		}
	}

	// Two-column header.
	themeHeader := s.dim.Render("Themes")
	themeHeaderPlain := "Themes"
	if pad := colWidth - len([]rune(themeHeaderPlain)); pad > 0 {
		themeHeader = themeHeader + strings.Repeat(" ", pad)
	}
	flavorHeader := s.dim.Render("Flavors")

	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Select Theme & Flavor"))
	bodyB.WriteString("\n\n")

	// Column headers.
	bodyB.WriteString("  " + themeHeader + "  " + flavorHeader)
	bodyB.WriteString("\n")

	// Interleave rows; pad shorter list with blank lines.
	maxRows := len(themeRows)
	if len(flavorRows) > maxRows {
		maxRows = len(flavorRows)
	}
	for i := 0; i < maxRows; i++ {
		left := ""
		if i < len(themeRows) {
			left = themeRows[i]
		} else {
			left = strings.Repeat(" ", colWidth)
		}
		right := ""
		if i < len(flavorRows) {
			right = flavorRows[i]
		}
		bodyB.WriteString("  " + left + "  " + right)
		bodyB.WriteString("\n")
	}

	// Preview block using hovered palette + dedicated syntax color fields.
	previewPalette := paletteFor(hoveredTheme, hoveredFlavor)
	kwStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Keyword))
	strStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.String))
	fnStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Function))
	cmtStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Comment))
	numStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Number))
	typeStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Type))
	normalStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Normal))
	dimStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(previewPalette.Dim))

	bodyB.WriteString("\n")
	bodyB.WriteString(dimStyle.Render("  Preview"))
	bodyB.WriteString("\n")
	bodyB.WriteString(dimStyle.Render("  ─────────────────────────────"))
	bodyB.WriteString("\n")
	bodyB.WriteString("  " + cmtStyle.Render("// demo: theme preview") + "\n")
	bodyB.WriteString("  " + kwStyle.Render("package") + normalStyle.Render(" main") + "\n")
	bodyB.WriteString("\n")
	bodyB.WriteString("  " + kwStyle.Render("import") + normalStyle.Render(" ") + strStyle.Render("\"fmt\"") + "\n")
	bodyB.WriteString("\n")
	bodyB.WriteString("  " + kwStyle.Render("type") + normalStyle.Render(" ") + fnStyle.Render("Greeter") + normalStyle.Render(" ") + kwStyle.Render("struct") + normalStyle.Render(" {") + "\n")
	bodyB.WriteString("  " + normalStyle.Render("    Count ") + typeStyle.Render("int") + "\n")
	bodyB.WriteString("  " + normalStyle.Render("}") + "\n")
	bodyB.WriteString("\n")
	bodyB.WriteString("  " + kwStyle.Render("func") + normalStyle.Render(" (g ") + fnStyle.Render("Greeter") + normalStyle.Render(") ") + fnStyle.Render("Hello") + normalStyle.Render("() {") + "\n")
	bodyB.WriteString("  " + normalStyle.Render("    fmt.") + fnStyle.Render("Println") + normalStyle.Render("(") + strStyle.Render("\"Hello, Theme!\"") + normalStyle.Render(", g.Count, ") + numStyle.Render("42") + normalStyle.Render(")") + "\n")
	bodyB.WriteString("  " + normalStyle.Render("}") + "\n")
	bodyB.WriteString(dimStyle.Render("  ─────────────────────────────"))
	bodyB.WriteString("\n\n")

	footer := RenderHelp([]HelpEntry{
		{Key: "↑/k", Action: "up"},
		{Key: "↓/j", Action: "down"},
		{Key: "Tab", Action: "switch panel"},
		{Key: "Space", Action: "select"},
		{Key: "enter", Action: "continue"},
		{Key: "Esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, stepLine, bodyB.String(), footer)
}

// stripANSIView is a local ANSI-strip helper for view padding calculations.
// Keeps only printable runes (filters escape sequences).
func stripANSIView(s string) string {
	var b strings.Builder
	inEsc := false
	for _, r := range s {
		if r == '\x1b' {
			inEsc = true
			continue
		}
		if inEsc {
			if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
				inEsc = false
			}
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

func renderToolSelect(m Model) string {
	stepIdx := currentStepIndex(ScreenToolSelect)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Select Tools to Install"))
	bodyB.WriteString("\n")

	for i, tool := range m.Tools {
		checkbox := "[ ]"
		if tool.Selected {
			checkbox = s.selected.Render("[✓]")
		}

		if i == m.Cursor {
			bodyB.WriteString(s.selectedItem.Render("▸ " + checkbox + " " + tool.Name))
		} else {
			bodyB.WriteString(s.unselectedItem.Render(checkbox + " " + tool.Name))
		}
		bodyB.WriteString(s.dim.Render(" — " + tool.Description))
		bodyB.WriteString("\n")
	}

	footer := RenderHelp([]HelpEntry{
		{Key: "↑/k", Action: "up"},
		{Key: "↓/j", Action: "down"},
		{Key: "Space", Action: "toggle"},
		{Key: "enter", Action: "continue"},
		{Key: "Esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, stepLine, bodyB.String(), footer)
}

func renderBackupConfirm(m Model) string {
	stepIdx := currentStepIndex(ScreenBackupConfirm)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Existing Configs Detected"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.normal.Render("Some config files already exist. What would you like to do?"))
	bodyB.WriteString("\n\n")

	options := []string{
		"💾  Install with backup (recommended)",
		"⚡  Install without backup",
		"❌  Cancel and go back",
	}
	for i, opt := range options {
		marker := "  "
		if i == m.BackupChoice {
			marker = s.selected.Render("● ")
		}
		if i == m.Cursor {
			bodyB.WriteString(s.selectedItem.Render("▸ " + marker + opt))
		} else {
			bodyB.WriteString(s.unselectedItem.Render(marker + opt))
		}
		bodyB.WriteString("\n")
	}

	footer := RenderHelp([]HelpEntry{
		{Key: "↑/k", Action: "up"},
		{Key: "↓/j", Action: "down"},
		{Key: "Space", Action: "select"},
		{Key: "enter", Action: "continue"},
		{Key: "Esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, stepLine, bodyB.String(), footer)
}

func renderInstalling(m Model) string {
	stepIdx := currentStepIndex(ScreenInstalling)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Installing..."))
	bodyB.WriteString("\n")

	for _, step := range m.Steps {
		icon := s.pending.Render("○")
		nameStyle := s.pending

		switch step.Status {
		case StatusDone:
			icon = s.done.Render("●")
			nameStyle = s.done
		case StatusRunning:
			frame := spinnerFrames[m.SpinnerFrame%len(spinnerFrames)]
			icon = s.running.Render(frame)
			nameStyle = s.running
		case StatusFailed:
			icon = s.failed.Render("✗")
			nameStyle = s.failed
		case StatusSkipped:
			icon = s.dim.Render("○")
			nameStyle = s.dim
		}

		bodyB.WriteString(fmt.Sprintf("  %s %s", icon, nameStyle.Render(step.Name)))
		if step.Detail != "" {
			bodyB.WriteString(s.dim.Render(" (" + step.Detail + ")"))
		}
		bodyB.WriteString("\n")
	}

	if m.ShowDetails && len(m.LogLines) > 0 {
		var logB strings.Builder
		logB.WriteString(s.dim.Render("─ Logs ─"))
		logB.WriteString("\n")
		start := 0
		if len(m.LogLines) > 8 {
			start = len(m.LogLines) - 8
		}
		for _, line := range m.LogLines[start:] {
			logB.WriteString(s.dim.Render("  " + line))
			logB.WriteString("\n")
		}
		bodyB.WriteString("\n")
		bodyB.WriteString(s.box.Render(logB.String()))
	} else if !m.ShowDetails && len(m.LogLines) > 0 {
		bodyB.WriteString("\n")
		bodyB.WriteString(s.dim.Render("─ Logs ─"))
		bodyB.WriteString("\n")
		start := 0
		if len(m.LogLines) > 8 {
			start = len(m.LogLines) - 8
		}
		for _, line := range m.LogLines[start:] {
			bodyB.WriteString(s.dim.Render("  " + line))
			bodyB.WriteString("\n")
		}
	}

	footer := RenderHelp([]HelpEntry{
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, stepLine, bodyB.String(), footer)
}

func renderSummary(m Model) string {
	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("✅ Installation Complete!"))
	bodyB.WriteString("\n")

	bodyB.WriteString(s.normal.Render("Installed:"))
	bodyB.WriteString("\n")
	for _, tool := range m.Tools {
		if tool.Selected {
			bodyB.WriteString(s.done.Render("  ✓ " + tool.Name))
			bodyB.WriteString("\n")
		}
	}

	if m.BackupDir != "" {
		bodyB.WriteString("\n")
		bodyB.WriteString(s.subtitle.Render("Backup saved to:"))
		bodyB.WriteString("\n")
		bodyB.WriteString(s.dim.Render("  " + m.BackupDir))
	}

	bodyB.WriteString("\n")
	bodyB.WriteString(s.subtitle.Render("Post-install steps:"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.dim.Render("  1. Open tmux: tmux new -s main"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.dim.Render("  2. Install TPM plugins: prefix + I (C-a I)"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.dim.Render("  3. Open nvim — plugins install automatically"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.dim.Render("  4. Restart your shell: exec zsh"))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "exit"},
	}, m.Palette, m.Width)

	return renderChrome(m, "", bodyB.String(), footer)
}

func renderError(m Model) string {
	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.failed.Render("❌ Error"))
	bodyB.WriteString("\n\n")
	bodyB.WriteString(s.normal.Render(m.ErrorMsg))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "exit"},
	}, m.Palette, m.Width)

	return renderChrome(m, "", bodyB.String(), footer)
}

// renderKeymapScreen renders a generic keymap/alias help screen for a given tool.
// It is called by the per-tool keymaps_<tool>.go screen renderers.
func renderKeymapScreen(m Model, title string, entries []KeymapEntry) string {
	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render(title))
	bodyB.WriteString("\n")
	for _, e := range entries {
		bodyB.WriteString(s.selected.Render(fmt.Sprintf("  %-30s", e.Key)))
		bodyB.WriteString(s.dim.Render(e.Description))
		bodyB.WriteString("\n")
	}

	footer := RenderHelp([]HelpEntry{
		{Key: "Esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, "", bodyB.String(), footer)
}
