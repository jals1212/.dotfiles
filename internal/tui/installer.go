package tui

import (
	"fmt"
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
func SendLog(m *Model, stepID, message string) {
	if m.IsNonInteractive {
		fmt.Printf("[%s] %s\n", stepID, message)
		return
	}
	m.LogLines = append(m.LogLines, fmt.Sprintf("[%s] %s", stepID, message))
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
