package tui

import (
	"fmt"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

// StepError provides context about which step failed
type StepError struct {
	StepID      string
	StepName    string
	Description string
	Cause       error
}

func (e *StepError) Error() string {
	return fmt.Sprintf("Step '%s' failed: %v", e.StepName, e.Cause)
}

func wrapStepError(stepID, stepName, description string, cause error) error {
	return &StepError{StepID: stepID, StepName: stepName, Description: description, Cause: cause}
}

// SendLog logs a message for the given step.
// In non-interactive mode it prints to stdout; in TUI mode it appends to model logs.
// When QuietLogs is set the message is appended to LogLines silently so callers
// can decide whether and how to surface them.
func SendLog(m *Model, stepID, message string) {
	if m.QuietLogs {
		m.LogLines = append(m.LogLines, fmt.Sprintf("[%s] %s", stepID, message))
		return
	}
	if m.IsNonInteractive {
		fmt.Printf("[%s] %s\n", stepID, message)
		return
	}
	m.LogLines = append(m.LogLines, fmt.Sprintf("[%s] %s", stepID, message))
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
	if selected["ghostty"] || selected["tmux"] || selected["nvim"] || selected["oh-my-posh"] || selected["atuin"] || selected["zoxide"] || selected["zsh"] {
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

// ExecuteStep runs the actual installation for a step.
func ExecuteStep(stepID string, m *Model) error {
	switch stepID {
	case "backup":
		return stepBackupConfigs(m)
	case "packages":
		return stepInstallPackages(m)
	case "deploy":
		return stepDeployConfigs(m)
	case "manifest":
		return stepSaveManifest(m)
	default:
		return fmt.Errorf("unknown step: %s", stepID)
	}
}
