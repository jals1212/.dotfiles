package tui

import (
	tea "github.com/charmbracelet/bubbletea"
)

// Update implements the tea.Model interface by dispatching to the update function.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	return update(m, msg)
}

type spinnerTickMsg struct{}

type installStepMsg struct {
	stepIdx   int
	status    StepStatus
	detail    string
	backupDir string
	logs      []string
}

type installCompleteMsg struct{}

func update(m Model, msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.Quitting = true
			return m, tea.Quit

		case "up", "k":
			if m.Screen == ScreenThemeFlavor {
				m = handleThemeFlavorUp(m)
			} else if m.Cursor > 0 {
				m.Cursor--
			}

		case "down", "j":
			if m.Screen == ScreenThemeFlavor {
				m = handleThemeFlavorDown(m)
			} else {
				max := maxCursor(m)
				if m.Cursor < max {
					m.Cursor++
				}
			}

		case "tab":
			if m.Screen == ScreenThemeFlavor {
				m = handleThemeFlavorTab(m)
			}

		case " ":
			switch m.Screen {
			case ScreenThemeFlavor:
				themes := defaultThemes()
				switch m.Panel {
				case 0: // Themes panel — commit hovered theme; reset flavor to default.
					if m.Cursor < len(themes) {
						m.SelectedTheme = themes[m.Cursor].Name
						m.SelectedFlavor = defaultFlavorForTheme(m.SelectedTheme)
						m.Palette = paletteFor(m.SelectedTheme, m.SelectedFlavor)
						// Cursor and Panel unchanged.
					}
				case 1: // Flavors panel — commit hovered flavor.
					flavors := defaultFlavorsForTheme(m.SelectedTheme)
					if m.Cursor < len(flavors) {
						m.SelectedFlavor = flavors[m.Cursor]
						m.Palette = paletteFor(m.SelectedTheme, m.SelectedFlavor)
						// Cursor and Panel unchanged.
					}
				}
			case ScreenToolSelect:
				if m.Cursor < len(m.Tools) {
					m.Tools[m.Cursor].Selected = !m.Tools[m.Cursor].Selected
				}
			case ScreenBackupConfirm:
				m.BackupChoice = m.Cursor
			}

		case "enter":
			return handleEnter(m)

		case "esc":
			switch m.Screen {
			case ScreenThemeFlavor:
				// Save current state so returning from ToolSelect restores it.
				m.PrevCursor = m.Cursor
				m.PrevPanel = m.Panel
				m.Screen = ScreenWelcome
				m.Cursor = 0
				m.Panel = 0
			case ScreenToolSelect:
				m.Screen = ScreenThemeFlavor
				m.Cursor = m.PrevCursor
				m.Panel = m.PrevPanel
			default:
				if m.Screen != ScreenWelcome {
					m.Screen = m.PrevScreen
					m.Cursor = 0
				}
			}
		}

	case spinnerTickMsg:
		if m.Screen == ScreenInstalling {
			m.SpinnerFrame++
			return m, nextTick()
		}

	case installStepMsg:
		if msg.stepIdx < len(m.Steps) {
			m.Steps[msg.stepIdx].Status = msg.status
			if msg.detail != "" {
				m.Steps[msg.stepIdx].Detail = msg.detail
			}
			if msg.backupDir != "" {
				m.BackupDir = msg.backupDir
			}
			if len(msg.logs) > 0 {
				m.LogLines = append(m.LogLines, msg.logs...)
			}
			if msg.status == StatusDone || msg.status == StatusFailed || msg.status == StatusSkipped {
				m.CurrentStep++
				if m.CurrentStep >= len(m.Steps) {
					m.PrevScreen = m.Screen
					m.Screen = ScreenSummary
				} else {
					m.Steps[m.CurrentStep].Status = StatusRunning
					return m, runInstallStep(m.CurrentStep, m)
				}
			}
		}
		return m, nil

	case installCompleteMsg:
		m.PrevScreen = m.Screen
		m.Screen = ScreenSummary
		return m, nil
	}

	return m, nil
}

func handleEnter(m Model) (tea.Model, tea.Cmd) {
	switch m.Screen {
	case ScreenWelcome:
		m.PrevScreen = m.Screen
		m.Screen = ScreenThemeFlavor
		m.Panel = 0
		// Position cursor on the currently selected theme.
		themes := defaultThemes()
		m.Cursor = 0
		for i, th := range themes {
			if th.Name == m.SelectedTheme {
				m.Cursor = i
				break
			}
		}

	case ScreenThemeFlavor:
		// Enter always advances to ToolSelect regardless of Panel.
		m.PrevCursor = m.Cursor
		m.PrevPanel = m.Panel
		m.PrevScreen = m.Screen
		m.Screen = ScreenToolSelect
		m.Cursor = 0
		m.Panel = 0

	case ScreenToolSelect:
		// Enter advances via startInstall on any tool row.
		return startInstall(m)

	case ScreenBackupConfirm:
		// Enter dispatches based on committed BackupChoice.
		switch m.BackupChoice {
		case 0: // Install with backup
			return startInstalling(m, true)
		case 1: // Install without backup
			return startInstalling(m, false)
		case 2: // Cancel — return to ToolSelect
			m.PrevScreen = m.Screen
			m.Screen = ScreenToolSelect
			m.Cursor = m.PrevCursor
		}

	case ScreenSummary:
		m.Quitting = true
		return m, tea.Quit
	}

	return m, nil
}

func maxCursor(m Model) int {
	switch m.Screen {
	case ScreenWelcome:
		return 0
	case ScreenThemeFlavor:
		// ScreenThemeFlavor navigation is handled by handleThemeFlavorUp/Down;
		// maxCursor is only consulted for the generic down handler (which is bypassed).
		return 0
	case ScreenToolSelect:
		return len(m.Tools) - 1
	case ScreenBackupConfirm:
		return 2
	case ScreenInstalling:
		return 0
	case ScreenSummary:
		return 0
	default:
		return 0
	}
}

// handleThemeFlavorUp moves the cursor up within the focused panel of ScreenThemeFlavor.
// Up past the first item of a panel does not wrap and does not change panel.
func handleThemeFlavorUp(m Model) Model {
	if m.Cursor > 0 {
		m.Cursor--
	}
	return m
}

// handleThemeFlavorDown moves the cursor down within the focused panel of ScreenThemeFlavor.
// Down at the last row stops; it does NOT advance to a different panel. Tab is the only panel switch.
func handleThemeFlavorDown(m Model) Model {
	switch m.Panel {
	case 0: // Themes
		themes := defaultThemes()
		if m.Cursor < len(themes)-1 {
			m.Cursor++
		}
		// At last row: no-op (no auto-advance to Flavors panel).
	case 1: // Flavors
		flavors := defaultFlavorsForTheme(m.SelectedTheme)
		if m.Cursor < len(flavors)-1 {
			m.Cursor++
		}
		// At last row: no-op (no Continue panel to advance to).
	}
	return m
}

// handleThemeFlavorTab cycles panel focus between Themes (0) and Flavors (1).
// Cursor is restored to the index of the selected item when entering a panel.
func handleThemeFlavorTab(m Model) Model {
	m.Panel = (m.Panel + 1) % 2
	switch m.Panel {
	case 0: // Themes
		themes := defaultThemes()
		m.Cursor = 0
		for i, th := range themes {
			if th.Name == m.SelectedTheme {
				m.Cursor = i
				break
			}
		}
	case 1: // Flavors
		flavors := defaultFlavorsForTheme(m.SelectedTheme)
		m.Cursor = 0
		for i, fl := range flavors {
			if fl == m.SelectedFlavor {
				m.Cursor = i
				break
			}
		}
	}
	return m
}

