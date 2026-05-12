package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#cba6f7")).
			MarginBottom(1)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6adc8")).
			MarginBottom(1)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6e3a1")).
			Bold(true)

	cursorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f5e0dc"))

	normalStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#cdd6f4"))

	dimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#6c7086"))

	doneStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#a6e3a1"))

	runningStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f9e2af"))

	failedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f38ba8"))

	pendingStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#6c7086"))
)

var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

func renderView(m Model) string {
	switch m.Screen {
	case ScreenWelcome:
		return renderWelcome(m)
	case ScreenFlavorSelect:
		return renderFlavorSelect(m)
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
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("╔══════════════════════════════════════╗"))
	b.WriteString("\n")
	b.WriteString(titleStyle.Render("║        dots — Dotfiles Manager       ║"))
	b.WriteString("\n")
	b.WriteString(titleStyle.Render("╚══════════════════════════════════════╝"))
	b.WriteString("\n\n")
	b.WriteString(subtitleStyle.Render("Manage your development environment with style."))
	b.WriteString("\n")
	b.WriteString(subtitleStyle.Render(fmt.Sprintf("Detected: %s (%s)", m.SystemInfo.OSName, m.SystemInfo.Arch)))
	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("Press enter to continue..."))
	return b.String()
}

func renderFlavorSelect(m Model) string {
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("Select Catppuccin Flavor"))
	b.WriteString("\n\n")

	flavors := defaultFlavors()
	for i, flavor := range flavors {
		radio := "○"
		if flavor == m.SelectedFlavor {
			radio = selectedStyle.Render("●")
		}

		prefix := "  "
		nameStyle := normalStyle
		if i == m.Cursor {
			prefix = cursorStyle.Render("❯ ")
			nameStyle = selectedStyle
		}

		b.WriteString(prefix)
		b.WriteString(radio)
		b.WriteString(" ")
		b.WriteString(nameStyle.Render(flavor))
		b.WriteString("\n")
	}

	// Continue button
	prefix := "  "
	btnStyle := normalStyle
	if m.Cursor == len(flavors) {
		prefix = cursorStyle.Render("❯ ")
		btnStyle = selectedStyle
	}
	b.WriteString("\n")
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("Continue"))
	b.WriteString("\n")

	b.WriteString("\n")
	b.WriteString(dimStyle.Render("enter select • j/k navigate • q quit"))
	return b.String()
}

func renderToolSelect(m Model) string {
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("Select Tools to Install"))
	b.WriteString("\n\n")

	for i, tool := range m.Tools {
		checkbox := "[ ]"
		if tool.Selected {
			checkbox = selectedStyle.Render("[✓]")
		}

		prefix := "  "
		nameStyle := normalStyle
		if i == m.Cursor {
			prefix = cursorStyle.Render("❯ ")
			nameStyle = selectedStyle
		}

		b.WriteString(prefix)
		b.WriteString(checkbox)
		b.WriteString(" ")
		b.WriteString(nameStyle.Render(tool.Name))
		b.WriteString(dimStyle.Render(" — " + tool.Description))
		b.WriteString("\n")
	}

	// Install button
	prefix := "  "
	btnStyle := normalStyle
	if m.Cursor == len(m.Tools) {
		prefix = cursorStyle.Render("❯ ")
		btnStyle = selectedStyle
	}
	b.WriteString("\n")
	b.WriteString(prefix)
	b.WriteString(btnStyle.Render("🚀  Install Selected"))
	b.WriteString("\n")

	b.WriteString("\n")
	b.WriteString(dimStyle.Render("space toggle • j/k navigate • enter install • q quit"))
	return b.String()
}

func renderBackupConfirm(m Model) string {
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("Existing Configs Detected"))
	b.WriteString("\n\n")
	b.WriteString(normalStyle.Render("Some config files already exist. What would you like to do?"))
	b.WriteString("\n\n")

	options := []string{
		"💾  Install with backup (recommended)",
		"⚡  Install without backup",
		"❌  Cancel and go back",
	}
	for i, opt := range options {
		prefix := "  "
		style := normalStyle
		if i == m.Cursor {
			prefix = cursorStyle.Render("❯ ")
			style = selectedStyle
		}
		b.WriteString(prefix)
		b.WriteString(style.Render(opt))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(dimStyle.Render("j/k navigate • enter select • q quit"))
	return b.String()
}

func renderInstalling(m Model) string {
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("Installing..."))
	b.WriteString("\n\n")

	for _, step := range m.Steps {
		icon := pendingStyle.Render("○")
		nameStyle := pendingStyle

		switch step.Status {
		case StatusDone:
			icon = doneStyle.Render("●")
			nameStyle = doneStyle
		case StatusRunning:
			frame := spinnerFrames[m.SpinnerFrame%len(spinnerFrames)]
			icon = runningStyle.Render(frame)
			nameStyle = runningStyle
		case StatusFailed:
			icon = failedStyle.Render("✗")
			nameStyle = failedStyle
		case StatusSkipped:
			icon = dimStyle.Render("○")
			nameStyle = dimStyle
		}

		b.WriteString(fmt.Sprintf("  %s %s", icon, nameStyle.Render(step.Name)))
		if step.Detail != "" {
			b.WriteString(dimStyle.Render(" (" + step.Detail + ")"))
		}
		b.WriteString("\n")
	}

	// Show recent logs
	if len(m.LogLines) > 0 {
		b.WriteString("\n")
		b.WriteString(dimStyle.Render("─ Logs ─"))
		b.WriteString("\n")
		start := 0
		if len(m.LogLines) > 8 {
			start = len(m.LogLines) - 8
		}
		for _, line := range m.LogLines[start:] {
			b.WriteString(dimStyle.Render("  " + line))
			b.WriteString("\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(dimStyle.Render("q quit"))
	return b.String()
}

func renderSummary(m Model) string {
	b := strings.Builder{}
	b.WriteString(titleStyle.Render("✅ Installation Complete!"))
	b.WriteString("\n\n")

	b.WriteString(normalStyle.Render("Installed:"))
	b.WriteString("\n")
	for _, tool := range m.Tools {
		if tool.Selected {
			b.WriteString(doneStyle.Render("  ✓ " + tool.Name))
			b.WriteString("\n")
		}
	}

	if m.BackupDir != "" {
		b.WriteString("\n")
		b.WriteString(subtitleStyle.Render("Backup saved to:"))
		b.WriteString("\n")
		b.WriteString(dimStyle.Render("  " + m.BackupDir))
	}

	b.WriteString("\n")
	b.WriteString(subtitleStyle.Render("Post-install steps:"))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render("  1. Open tmux: tmux new -s main"))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render("  2. Install TPM plugins: prefix + I (C-a I)"))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render("  3. Open nvim — plugins install automatically"))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render("  4. Restart your shell: exec zsh"))
	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("Press enter or q to exit"))
	return b.String()
}

func renderError(m Model) string {
	b := strings.Builder{}
	b.WriteString(failedStyle.Render("❌ Error"))
	b.WriteString("\n\n")
	b.WriteString(normalStyle.Render(m.ErrorMsg))
	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("Press q to quit"))
	return b.String()
}
