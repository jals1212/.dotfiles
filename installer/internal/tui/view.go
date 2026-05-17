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

func renderWelcome(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("╔══════════════════════════════════════╗"))
	b.WriteString("\n")
	b.WriteString(s.title.Render("║        dots — Dotfiles Manager       ║"))
	b.WriteString("\n")
	b.WriteString(s.title.Render("╚══════════════════════════════════════╝"))
	b.WriteString("\n\n")
	b.WriteString(s.subtitle.Render("Manage your development environment with style."))
	b.WriteString("\n")
	b.WriteString(s.subtitle.Render(fmt.Sprintf("Detected: %s (%s)", m.SystemInfo.OSName, m.SystemInfo.Arch)))
	b.WriteString("\n\n")
	b.WriteString(s.dim.Render("Press enter to continue..."))
	return b.String()
}

func renderThemeSelect(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("Select Theme"))
	b.WriteString("\n\n")

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

		b.WriteString(prefix)
		b.WriteString(radio)
		b.WriteString(" ")
		b.WriteString(nameStyle.Render(theme.DisplayName))
		b.WriteString(s.dim.Render(" — " + theme.Description))
		b.WriteString("\n")
	}

	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(themes) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	b.WriteString("\n")
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("Continue"))
	b.WriteString("\n\n")
	b.WriteString(s.dim.Render("enter select • j/k navigate • q quit"))
	return b.String()
}

func renderFlavorSelect(m Model) string {
	theme, selectedFlavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render(fmt.Sprintf("Select %s Flavor", strings.Title(theme))))
	b.WriteString("\n\n")

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

		b.WriteString(prefix)
		b.WriteString(radio)
		b.WriteString(" ")
		b.WriteString(nameStyle.Render(flavor))
		b.WriteString("\n")
	}

	// Continue button
	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(flavors) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	b.WriteString("\n")
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("Continue"))
	b.WriteString("\n")

	b.WriteString("\n")
	b.WriteString(s.dim.Render("enter select • j/k navigate • q quit"))
	return b.String()
}

func renderThemePreview(m Model) string {
	theme, flavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("Theme Preview"))
	b.WriteString("\n\n")
	b.WriteString(s.subtitle.Render(fmt.Sprintf("Selected: %s/%s", theme, flavor)))
	b.WriteString("\n")

	// Sample code block with syntax highlighting
	keywordStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Title))
	stringStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Selected))
	normalCodeStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Normal))
	funcStyle := lipgloss.NewStyle().Foreground(lipgloss.Color(m.Palette.Done))

	b.WriteString(s.dim.Render("Sample Go code:"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("─────────────────────────────"))
	b.WriteString("\n")
	b.WriteString(keywordStyle.Render("package") + normalCodeStyle.Render(" main\n"))
	b.WriteString(keywordStyle.Render("import") + normalCodeStyle.Render(" ") + stringStyle.Render("\"fmt\"") + normalCodeStyle.Render("\n"))
	b.WriteString(keywordStyle.Render("func") + normalCodeStyle.Render(" ") + funcStyle.Render("main") + normalCodeStyle.Render("() {\n"))
	b.WriteString(normalCodeStyle.Render("    fmt.") + funcStyle.Render("Println") + normalCodeStyle.Render("(") + stringStyle.Render("\"Hello, Theme!\"") + normalCodeStyle.Render(")\n"))
	b.WriteString(normalCodeStyle.Render("}\n"))
	b.WriteString(s.dim.Render("─────────────────────────────"))
	b.WriteString("\n\n")

	// Continue button
	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == 0 {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("Continue (Enter)"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("  Back (Esc)"))
	b.WriteString("\n\n")
	b.WriteString(s.dim.Render("enter continue • esc back • q quit"))
	return b.String()
}

func renderToolSelect(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("Select Tools to Install"))
	b.WriteString("\n\n")

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

		b.WriteString(prefix)
		b.WriteString(checkbox)
		b.WriteString(" ")
		b.WriteString(nameStyle.Render(tool.Name))
		b.WriteString(s.dim.Render(" — " + tool.Description))
		b.WriteString("\n")
	}

	// Install button
	prefix := "  "
	btnStyle := s.normal
	if m.Cursor == len(m.Tools) {
		prefix = s.cursor.Render("❯ ")
		btnStyle = s.selected
	}
	b.WriteString("\n")
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("🚀  Install Selected"))
	b.WriteString("\n")

	b.WriteString("\n")
	b.WriteString(s.dim.Render("space toggle • j/k navigate • enter install • q quit"))
	return b.String()
}

func renderBackupConfirm(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("Existing Configs Detected"))
	b.WriteString("\n\n")
	b.WriteString(s.normal.Render("Some config files already exist. What would you like to do?"))
	b.WriteString("\n\n")

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
		b.WriteString(prefix)
		b.WriteString(style.Render(opt))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(s.dim.Render("j/k navigate • enter select • q quit"))
	return b.String()
}

func renderInstalling(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("Installing..."))
	b.WriteString("\n\n")

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

		b.WriteString(fmt.Sprintf("  %s %s", icon, nameStyle.Render(step.Name)))
		if step.Detail != "" {
			b.WriteString(s.dim.Render(" (" + step.Detail + ")"))
		}
		b.WriteString("\n")
	}

	// Show recent logs
	if len(m.LogLines) > 0 {
		b.WriteString("\n")
		b.WriteString(s.dim.Render("─ Logs ─"))
		b.WriteString("\n")
		start := 0
		if len(m.LogLines) > 8 {
			start = len(m.LogLines) - 8
		}
		for _, line := range m.LogLines[start:] {
			b.WriteString(s.dim.Render("  " + line))
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(s.dim.Render("q quit"))
	return b.String()
}

func renderSummary(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render("✅ Installation Complete!"))
	b.WriteString("\n\n")

	b.WriteString(s.normal.Render("Installed:"))
	b.WriteString("\n")
	for _, tool := range m.Tools {
		if tool.Selected {
			b.WriteString(s.done.Render("  ✓ " + tool.Name))
			b.WriteString("\n")
		}
	}

	if m.BackupDir != "" {
		b.WriteString("\n")
		b.WriteString(s.subtitle.Render("Backup saved to:"))
		b.WriteString("\n")
		b.WriteString(s.dim.Render("  " + m.BackupDir))
	}

	b.WriteString("\n")
	b.WriteString(s.subtitle.Render("Post-install steps:"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("  1. Open tmux: tmux new -s main"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("  2. Install TPM plugins: prefix + I (C-a I)"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("  3. Open nvim — plugins install automatically"))
	b.WriteString("\n")
	b.WriteString(s.dim.Render("  4. Restart your shell: exec zsh"))
	b.WriteString("\n\n")
	b.WriteString(s.dim.Render("Press enter or q to exit"))
	return b.String()
}

func renderError(m Model) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.failed.Render("❌ Error"))
	b.WriteString("\n\n")
	b.WriteString(s.normal.Render(m.ErrorMsg))
	b.WriteString("\n\n")
	b.WriteString(s.dim.Render("Press q to quit"))
	return b.String()
}

// renderKeymapScreen renders a generic keymap/alias help screen for a given tool.
// It is called by the per-tool keymaps_<tool>.go screen renderers.
func renderKeymapScreen(m Model, title string, entries []KeymapEntry) string {
	s := getStyles(m.Palette)
	b := strings.Builder{}
	b.WriteString(s.title.Render(title))
	b.WriteString("\n\n")
	for _, e := range entries {
		b.WriteString(s.selected.Render(fmt.Sprintf("  %-30s", e.Key)))
		b.WriteString(s.dim.Render(e.Description))
		b.WriteString("\n")
	}
	b.WriteString("\n")
	b.WriteString(s.dim.Render("esc back • q quit"))
	return b.String()
}
