package tui

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

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
			if m.Cursor > 0 {
				m.Cursor--
			}

		case "down", "j":
			max := maxCursor(m)
			if m.Cursor < max {
				m.Cursor++
			}

		case " ":
			if m.Screen == ScreenToolSelect && m.Cursor < len(m.Tools) {
				m.Tools[m.Cursor].Selected = !m.Tools[m.Cursor].Selected
			}

		case "enter":
			return handleEnter(m)

		case "esc":
			if m.Screen != ScreenWelcome {
				m.Screen = m.PrevScreen
				m.Cursor = 0
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
		m.Screen = ScreenThemeSelect
		m.Cursor = 0

	case ScreenThemeSelect:
		themes := defaultThemes()
		if m.Cursor < len(themes) {
			m.SelectedTheme = themes[m.Cursor].Name
			m.SelectedFlavor = themes[m.Cursor].DefaultFlavor
			m.Palette = paletteFor(m.SelectedTheme, m.SelectedFlavor)
		} else if m.Cursor == len(themes) {
			m.PrevScreen = m.Screen
			m.Screen = ScreenFlavorSelect
			m.Cursor = 0
		}

	case ScreenFlavorSelect:
		m.SelectedTheme, m.SelectedFlavor = normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
		flavors := defaultFlavorsForTheme(m.SelectedTheme)
		if m.Cursor < len(flavors) {
			m.SelectedFlavor = flavors[m.Cursor]
			m.Palette = paletteFor(m.SelectedTheme, m.SelectedFlavor)
		} else if m.Cursor == len(flavors) {
			m.PrevScreen = m.Screen
			m.Screen = ScreenThemePreview
			m.Cursor = 0
		}

	case ScreenThemePreview:
		m.PrevScreen = m.Screen
		m.Screen = ScreenToolSelect
		m.Cursor = 0

	case ScreenToolSelect:
		// Last option is "Install"
		if m.Cursor == len(m.Tools) {
			return startInstall(m)
		}
		// Toggle tool
		if m.Cursor < len(m.Tools) {
			m.Tools[m.Cursor].Selected = !m.Tools[m.Cursor].Selected
		}

	case ScreenBackupConfirm:
		switch m.Cursor {
		case 0: // Install with backup
			return startInstalling(m, true)
		case 1: // Install without backup
			return startInstalling(m, false)
		case 2: // Cancel
			m.PrevScreen = m.Screen
			m.Screen = ScreenToolSelect
			m.Cursor = 0
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
	case ScreenThemeSelect:
		return len(defaultThemes())
	case ScreenFlavorSelect:
		return len(defaultFlavorsForTheme(m.SelectedTheme))
	case ScreenThemePreview:
		return 0
	case ScreenToolSelect:
		return len(m.Tools)
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

func startInstall(m Model) (tea.Model, tea.Cmd) {
	m.ExistingConfigs = system.DetectExistingConfigs(system.OSFileSystem{}, m.SystemInfo.DotfilesDir, m.SystemInfo.HomeDir)
	hasExisting := len(m.ExistingConfigs) > 0

	if hasExisting {
		m.PrevScreen = m.Screen
		m.Screen = ScreenBackupConfirm
		m.Cursor = 0
		return m, nil
	}

	return startInstalling(m, false)
}

func startInstalling(m Model, backup bool) (tea.Model, tea.Cmd) {
	m.PrevScreen = m.Screen
	m.Screen = ScreenInstalling
	m.Steps = buildInstallSteps(m.Tools, backup)
	m.CurrentStep = 0
	m.LogLines = []string{}
	if len(m.Steps) > 0 {
		m.Steps[0].Status = StatusRunning
	}
	return m, tea.Batch(nextTick(), runInstallSteps(m))
}

func buildInstallSteps(tools []Tool, backup bool) []InstallStep {
	steps := []InstallStep{}

	if backup {
		steps = append(steps, InstallStep{ID: "backup", Name: "Backup existing configs"})
	}

	// Check which tools are selected
	selected := map[string]bool{}
	for _, t := range tools {
		if t.Selected {
			selected[t.Name] = true
		}
	}

	// Package installation step
	if selected["ghostty"] || selected["tmux"] || selected["nvim"] || selected["starship"] || selected["atuin"] || selected["zoxide"] || selected["zsh"] {
		steps = append(steps, InstallStep{ID: "packages", Name: "Install packages", Interactive: true})
	}

	// Deploy configs
	steps = append(steps, InstallStep{ID: "deploy", Name: "Deploy configs"})

	steps = append(steps, InstallStep{ID: "manifest", Name: "Save manifest"})

	return steps
}

func runInstallSteps(m Model) tea.Cmd {
	if len(m.Steps) == 0 {
		return func() tea.Msg {
			return installCompleteMsg{}
		}
	}
	return runInstallStep(0, m)
}

func runInstallStep(stepIdx int, m Model) tea.Cmd {
	return func() tea.Msg {
		if stepIdx >= len(m.Steps) {
			return installCompleteMsg{}
		}
		step := m.Steps[stepIdx]
		startLogs := len(m.LogLines)
		err := ExecuteStep(step.ID, &m)
		newLogs := m.LogLines[startLogs:]

		status := StatusDone
		detail := ""
		if err != nil {
			status = StatusFailed
			detail = err.Error()
		}

		return installStepMsg{
			stepIdx:   stepIdx,
			status:    status,
			detail:    detail,
			backupDir: m.BackupDir,
			logs:      newLogs,
		}
	}
}

func nextTick() tea.Cmd {
	return tea.Tick(200*time.Millisecond, func(_ time.Time) tea.Msg {
		return spinnerTickMsg{}
	})
}
