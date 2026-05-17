package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// View implements the tea.Model interface by routing to the per-screen renderer.
func (m Model) View() string {
	return renderView(m)
}

func renderView(m Model) string {
	switch m.Screen {
	case ScreenWelcome:
		return renderWelcome(m)
	case ScreenThemeSelect:
		return renderThemeSelect(m)
	case ScreenFlavorSelect:
		return renderFlavorSelect(m)
	case ScreenThemePreview:
		return renderThemePreview(m)
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
// header and footer are rendered outside the box.
// stepLine may be empty for off-funnel screens.
func renderChrome(m Model, header, stepLine, content, footer string) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(header)
	b.WriteString("\n")
	if stepLine != "" {
		b.WriteString(stepLine)
		b.WriteString("\n\n")
	}
	b.WriteString(s.box.Render(content))
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

	return renderChrome(m, header, "", bodyB.String(), footer)
}

func renderThemeSelect(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
	stepIdx := currentStepIndex(ScreenThemeSelect)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Select Theme"))
	bodyB.WriteString("\n")

	themes := defaultThemes()
	for i, theme := range themes {
		radio := "○"
		if theme.Name == m.SelectedTheme {
			radio = s.selected.Render("●")
		}

		prefix := "  "
		nameStyle := s.normal
		if i == m.Cursor {
			prefix = s.cursor.Render("❯ ")
			nameStyle = s.selected
		}

		bodyB.WriteString(prefix)
		bodyB.WriteString(radio)
		bodyB.WriteString(" ")
		bodyB.WriteString(nameStyle.Render(theme.DisplayName))
		bodyB.WriteString(s.dim.Render(" — " + theme.Description))
		bodyB.WriteString("\n")
	}

	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(themes) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	bodyB.WriteString("\n")
	bodyB.WriteString(prefix)
	bodyB.WriteString(btnStyle.Render("Continue"))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "select"},
		{Key: "j/k", Action: "navigate"},
		{Key: "esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderFlavorSelect(m Model) string {
	theme, selectedFlavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
	stepIdx := currentStepIndex(ScreenFlavorSelect)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render(fmt.Sprintf("Select %s Flavor", strings.Title(theme))))
	bodyB.WriteString("\n")

	flavors := defaultFlavorsForTheme(theme)
	for i, flavor := range flavors {
		radio := "○"
		if flavor == selectedFlavor {
			radio = s.selected.Render("●")
		}

		prefix := "  "
		nameStyle := s.normal
		if i == m.Cursor {
			prefix = s.cursor.Render("❯ ")
			nameStyle = s.selected
		}

		bodyB.WriteString(prefix)
		bodyB.WriteString(radio)
		bodyB.WriteString(" ")
		bodyB.WriteString(nameStyle.Render(flavor))
		bodyB.WriteString("\n")
	}

	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(flavors) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	bodyB.WriteString("\n")
	bodyB.WriteString(prefix)
	bodyB.WriteString(btnStyle.Render("Continue"))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "select"},
		{Key: "j/k", Action: "navigate"},
		{Key: "esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderThemePreview(m Model) string {
	theme, flavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
	stepIdx := currentStepIndex(ScreenThemePreview)
	stepLine := RenderSteps(installFunnelSteps(), stepIdx, m.Palette, m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.title.Render("Theme Preview"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.subtitle.Render(fmt.Sprintf("Selected: %s/%s", theme, flavor)))

	// Sample code block with syntax highlighting using palette colors (no hardcoded literals)
	keywordStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Title))
	stringStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Selected))
	normalCodeStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Normal))
	funcStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Done))

	bodyB.WriteString(s.dim.Render("Sample Go code:"))
	bodyB.WriteString("\n")
	bodyB.WriteString(s.dim.Render("─────────────────────────────"))
	bodyB.WriteString("\n")
	bodyB.WriteString(keywordStyle.Render("package") + normalCodeStyle.Render(" main\n"))
	bodyB.WriteString(keywordStyle.Render("import") + normalCodeStyle.Render(" ") + stringStyle.Render("\"fmt\"") + normalCodeStyle.Render("\n"))
	bodyB.WriteString(keywordStyle.Render("func") + normalCodeStyle.Render(" ") + funcStyle.Render("main") + normalCodeStyle.Render("() {\n"))
	bodyB.WriteString(normalCodeStyle.Render("    fmt.") + funcStyle.Render("Println") + normalCodeStyle.Render("(") + stringStyle.Render("\"Hello, Theme!\"") + normalCodeStyle.Render(")\n"))
	bodyB.WriteString(normalCodeStyle.Render("}\n"))
	bodyB.WriteString(s.dim.Render("─────────────────────────────"))
	bodyB.WriteString("\n\n")

	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == 0 {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	bodyB.WriteString(prefix)
	bodyB.WriteString(btnStyle.Render("Continue (Enter)"))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "continue"},
		{Key: "esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderToolSelect(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
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

		prefix := "  "
		nameStyle := s.normal
		if i == m.Cursor {
			prefix = s.cursor.Render("❯ ")
			nameStyle = s.selected
		}

		bodyB.WriteString(prefix)
		bodyB.WriteString(checkbox)
		bodyB.WriteString(" ")
		bodyB.WriteString(nameStyle.Render(tool.Name))
		bodyB.WriteString(s.dim.Render(" — " + tool.Description))
		bodyB.WriteString("\n")
	}

	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(m.Tools) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	bodyB.WriteString("\n")
	bodyB.WriteString(prefix)
	bodyB.WriteString(btnStyle.Render("🚀  Install Selected"))

	footer := RenderHelp([]HelpEntry{
		{Key: "space", Action: "toggle"},
		{Key: "enter", Action: "continue"},
		{Key: "j/k", Action: "navigate"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderBackupConfirm(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
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
		prefix := "  "
		style := s.normal
		if i == m.Cursor {
			prefix = s.cursor.Render("❯ ")
			style = s.selected
		}
		bodyB.WriteString(prefix)
		bodyB.WriteString(style.Render(opt))
		bodyB.WriteString("\n")
	}

	footer := RenderHelp([]HelpEntry{
		{Key: "j/k", Action: "navigate"},
		{Key: "enter", Action: "select"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderInstalling(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)
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

	if len(m.LogLines) > 0 {
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

	return renderChrome(m, header, stepLine, bodyB.String(), footer)
}

func renderSummary(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)

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

	return renderChrome(m, header, "", bodyB.String(), footer)
}

func renderError(m Model) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)

	s := getStyles(m.Palette)
	var bodyB strings.Builder
	bodyB.WriteString(s.failed.Render("❌ Error"))
	bodyB.WriteString("\n\n")
	bodyB.WriteString(s.normal.Render(m.ErrorMsg))

	footer := RenderHelp([]HelpEntry{
		{Key: "enter", Action: "exit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, "", bodyB.String(), footer)
}

// renderKeymapScreen renders a generic keymap/alias help screen for a given tool.
// It is called by the per-tool keymaps_<tool>.go screen renderers.
func renderKeymapScreen(m Model, title string, entries []KeymapEntry) string {
	header := RenderHeader(m.Palette, "Dotfiles Manager", m.Width)

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
		{Key: "esc", Action: "back"},
		{Key: "q", Action: "quit"},
	}, m.Palette, m.Width)

	return renderChrome(m, header, "", bodyB.String(), footer)
}
