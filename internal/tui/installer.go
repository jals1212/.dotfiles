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
	logFn := func(line string) {
		SendLog(m, stepID, line)
	}
	if m.SystemInfo.HasBrew {
		cmd := fmt.Sprintf("brew install %s", strings.Join(packages, " "))
		result := system.RunWithLogs(cmd, nil, logFn)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: brew install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSDebian {
		cmd := fmt.Sprintf("apt-get install -y %s", strings.Join(packages, " "))
		result := system.RunSudoWithLogs(cmd, nil, logFn)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: apt install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSFedora {
		cmd := fmt.Sprintf("dnf install -y %s", strings.Join(packages, " "))
		result := system.RunSudoWithLogs(cmd, nil, logFn)
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("Warning: dnf install had issues: %v", result.Error))
		}
	} else if m.SystemInfo.OS == system.OSArch {
		cmd := fmt.Sprintf("pacman -S --noconfirm %s", strings.Join(packages, " "))
		result := system.RunSudoWithLogs(cmd, nil, logFn)
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
	flavor := m.SelectedFlavor

	// Deploy .config/* to ~/.config/*
	configSource := filepath.Join(dotfilesDir, "home", ".config")
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
					if err := replaceInDir(dst, "CATPPUCCIN_FLAVOR", flavor); err != nil {
						SendLog(m, stepID, fmt.Sprintf("  ⚠ Replace failed: %v", err))
					}
				}
			} else {
				if err := system.CopyFile(src, dst); err != nil {
					SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
				} else {
					SendLog(m, stepID, fmt.Sprintf("  ✓ %s", entry.Name()))
					if err := system.ReplaceInFile(dst, "CATPPUCCIN_FLAVOR", flavor); err != nil {
						SendLog(m, stepID, fmt.Sprintf("  ⚠ Replace failed: %v", err))
					}
				}
			}
		}
	}

	// Deploy home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		src := filepath.Join(dotfilesDir, "home", f)
		if _, err := os.Stat(src); err == nil {
			dst := filepath.Join(homeDir, f)
			SendLog(m, stepID, fmt.Sprintf("Deploying %s...", f))
			if err := system.CopyFile(src, dst); err != nil {
				SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
			} else {
				SendLog(m, stepID, fmt.Sprintf("  ✓ %s", f))
				if err := system.ReplaceInFile(dst, "CATPPUCCIN_FLAVOR", flavor); err != nil {
					SendLog(m, stepID, fmt.Sprintf("  ⚠ Replace failed: %v", err))
				}
			}
		}
	}

	// 4.4 Starship palette
	starshipSrc := filepath.Join(dotfilesDir, "assets", "themes", "starship", fmt.Sprintf("%s.toml", flavor))
	starshipDst := filepath.Join(homeDir, ".config", "starship", "themes", fmt.Sprintf("%s.toml", flavor))
	if err := system.CopyFile(starshipSrc, starshipDst); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ Starship theme failed: %v", err))
	} else {
		SendLog(m, stepID, "✓ Starship theme deployed")
	}

	// 4.5 Atuin theme
	atuinSrc := filepath.Join(dotfilesDir, "assets", "themes", "atuin", fmt.Sprintf("catppuccin-%s-mauve.toml", flavor))
	atuinDst := filepath.Join(homeDir, ".config", "atuin", "themes", fmt.Sprintf("catppuccin-%s-mauve.toml", flavor))
	if err := system.CopyFile(atuinSrc, atuinDst); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ Atuin theme failed: %v", err))
	} else {
		SendLog(m, stepID, "✓ Atuin theme deployed")
	}

	// 4.6 Bottom theme
	bottomSrc := filepath.Join(dotfilesDir, "assets", "themes", "bottom", fmt.Sprintf("%s.toml", flavor))
	bottomDst := filepath.Join(homeDir, ".config", "bottom", "bottom.toml")
	if err := system.CopyFile(bottomSrc, bottomDst); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ Bottom theme failed: %v", err))
	} else {
		SendLog(m, stepID, "✓ Bottom theme deployed")
	}

	// 4.7 Lazygit theme
	lazygitSrc := filepath.Join(dotfilesDir, "assets", "themes", "lazygit", fmt.Sprintf("%s.yml", flavor))
	lazygitDst := filepath.Join(homeDir, ".config", "lazygit", "config.yml")
	if err := system.CopyFile(lazygitSrc, lazygitDst); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ Lazygit theme failed: %v", err))
	} else {
		SendLog(m, stepID, "✓ Lazygit theme deployed")
	}

	// 4.8 Bat theme
	batSrc := filepath.Join(dotfilesDir, "assets", "themes", "bat", fmt.Sprintf("Catppuccin-%s.tmTheme", flavor))
	batDst := filepath.Join(homeDir, ".config", "bat", "themes", fmt.Sprintf("Catppuccin-%s.tmTheme", flavor))
	if err := system.CopyFile(batSrc, batDst); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ Bat theme failed: %v", err))
	} else {
		SendLog(m, stepID, "✓ Bat theme deployed")
		result := system.RunWithLogs("bat cache --build", nil, func(line string) {
			SendLog(m, stepID, line)
		})
		if result.Error != nil {
			SendLog(m, stepID, fmt.Sprintf("⚠ Bat cache build failed: %v", result.Error))
		}
	}
	batEnv := fmt.Sprintf(`export BAT_THEME="Catppuccin %s"`, flavor)
	if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_BAT_START", "# CATPPUCCIN_BAT_END", batEnv); err != nil {
		SendLog(m, stepID, fmt.Sprintf("⚠ BAT_THEME setup failed: %v", err))
	}

	// 4.9 Eza colors
	ezaSrc := filepath.Join(dotfilesDir, "assets", "themes", "eza", fmt.Sprintf("%s.txt", flavor))
	if ezaData, err := os.ReadFile(ezaSrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_EZA_START", "# CATPPUCCIN_EZA_END", string(ezaData)); err != nil {
			SendLog(m, stepID, fmt.Sprintf("⚠ Eza colors setup failed: %v", err))
		} else {
			SendLog(m, stepID, "✓ Eza colors deployed")
		}
	} else {
		SendLog(m, stepID, fmt.Sprintf("⚠ Eza colors read failed: %v", err))
	}

	// 4.10 fzf colors
	fzfSrc := filepath.Join(dotfilesDir, "assets", "themes", "fzf", fmt.Sprintf("%s.sh", flavor))
	if fzfData, err := os.ReadFile(fzfSrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_FZF_START", "# CATPPUCCIN_FZF_END", string(fzfData)); err != nil {
			SendLog(m, stepID, fmt.Sprintf("⚠ Fzf colors setup failed: %v", err))
		} else {
			SendLog(m, stepID, "✓ Fzf colors deployed")
		}
	} else {
		SendLog(m, stepID, fmt.Sprintf("⚠ Fzf colors read failed: %v", err))
	}

	// 4.11 Ghostty theme
	ghosttySrc := filepath.Join(dotfilesDir, "assets", "themes", "ghostty", fmt.Sprintf("%s.conf", flavor))
	if ghosttyData, err := os.ReadFile(ghosttySrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".config", "ghostty", "config"), "# CATPPUCCIN_GHOSTTY_THEME_START", "# CATPPUCCIN_GHOSTTY_THEME_END", string(ghosttyData)); err != nil {
			SendLog(m, stepID, fmt.Sprintf("⚠ Ghostty theme setup failed: %v", err))
		} else {
			SendLog(m, stepID, "✓ Ghostty theme deployed")
		}
	} else {
		SendLog(m, stepID, fmt.Sprintf("⚠ Ghostty theme read failed: %v", err))
	}

	SendLog(m, stepID, "✓ All configs deployed")
	return nil
}

func replaceInDir(dir, old, new string) error {
	return filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return system.ReplaceInFile(path, old, new)
		}
		return nil
	})
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
