package tui

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

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

func stepBackupConfigs(m *Model) error {
	stepID := "backup"
	if len(m.ExistingConfigs) == 0 {
		SendLog(m, stepID, "No existing configs to backup")
		return nil
	}

	SendLog(m, stepID, fmt.Sprintf("Backing up %d existing configs...", len(m.ExistingConfigs)))

	backupDir, err := system.CreateBackup(m.ExistingConfigs)
	if err != nil {
		return fmt.Errorf("failed to create backup: %w", err)
	}

	m.BackupDir = backupDir
	SendLog(m, stepID, fmt.Sprintf("✓ Backup created at: %s", backupDir))
	return nil
}

func stepInstallPackages(m *Model) error {
	stepID := "packages"

	// Check which tools need packages
	selected := map[string]bool{}
	for _, t := range m.Tools {
		if t.Selected {
			selected[t.Name] = true
		}
	}

	// Build package list
	packages := []string{}
	if selected["tmux"] {
		packages = append(packages, "tmux")
	}
	if selected["nvim"] {
		packages = append(packages, "neovim")
	}
	if selected["starship"] {
		packages = append(packages, "starship")
	}
	if selected["atuin"] {
		packages = append(packages, "atuin")
	}
	if selected["zoxide"] {
		packages = append(packages, "zoxide")
	}
	if selected["ghostty"] && m.SystemInfo.OS == system.OSMac {
		packages = append(packages, "ghostty")
	}

	if len(packages) == 0 {
		SendLog(m, stepID, "No packages to install")
		return nil
	}

	SendLog(m, stepID, fmt.Sprintf("Installing: %s", strings.Join(packages, ", ")))

	// Use appropriate package manager
	if m.SystemInfo.HasBrew {
		cmd := fmt.Sprintf("brew install %s", strings.Join(packages, " "))
		result := system.Run(cmd, nil)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: brew install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSDebian {
		cmd := fmt.Sprintf("sudo apt-get install -y %s", strings.Join(packages, " "))
		result := system.Run(cmd, nil)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: apt install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSFedora {
		cmd := fmt.Sprintf("sudo dnf install -y %s", strings.Join(packages, " "))
		result := system.Run(cmd, nil)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: dnf install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSArch {
		cmd := fmt.Sprintf("sudo pacman -S --noconfirm %s", strings.Join(packages, " "))
		result := system.Run(cmd, nil)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: pacman install had issues: %v", result.Error))
		}
	}

	SendLog(m, stepID, "✓ Package installation complete")
	return nil
}

func stepDeployConfigs(m *Model) error {
	stepID := "deploy"
	homeDir := m.SystemInfo.HomeDir
	dotfilesDir := m.SystemInfo.DotfilesDir

	// Deploy .config/* to ~/.config/*
	configSource := filepath.Join(dotfilesDir, ".config")
	if entries, err := os.ReadDir(configSource); err == nil {
		for _, entry := range entries {
			src := filepath.Join(configSource, entry.Name())
			dst := filepath.Join(homeDir, ".config", entry.Name())

			SendLog(m, stepID, fmt.Sprintf("Deploying %s...", entry.Name()))

			if entry.IsDir() {
				if err := system.CopyDir(src, dst); err != nil {
					SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
				} else {
					SendLog(m, stepID, fmt.Sprintf("  ✓ %s/", entry.Name()))
				}
			} else {
				if err := system.CopyFile(src, dst); err != nil {
					SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
				} else {
					SendLog(m, stepID, fmt.Sprintf("  ✓ %s", entry.Name()))
				}
			}
		}
	}

	// Deploy home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		src := filepath.Join(dotfilesDir, f)
		if _, err := os.Stat(src); err == nil {
			dst := filepath.Join(homeDir, f)
			SendLog(m, stepID, fmt.Sprintf("Deploying %s...", f))
			if err := system.CopyFile(src, dst); err != nil {
				SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
			} else {
				SendLog(m, stepID, fmt.Sprintf("  ✓ %s", f))
			}
		}
	}

	SendLog(m, stepID, "✓ All configs deployed")
	return nil
}

func stepSaveManifest(m *Model) error {
	stepID := "manifest"
	dotfilesDir := m.SystemInfo.DotfilesDir

	manifest := struct {
		DeployedAt string `json:"deployed_at"`
		Version    string `json:"version"`
	}{
		DeployedAt: time.Now().Format(time.RFC3339),
		Version:    "1.0.0",
	}

	data, _ := json.MarshalIndent(manifest, "", "  ")
	manifestPath := filepath.Join(dotfilesDir, "manifest.json")
	os.WriteFile(manifestPath, data, 0644)

	SendLog(m, stepID, "✓ Manifest saved")
	return nil
}
