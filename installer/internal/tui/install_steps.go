package tui

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jals/dotfiles/internal/system"
)

func stepBackupConfigs(m *Model) error {
	stepID := "backup"
	if len(m.ExistingConfigs) == 0 {
		SendLog(m, stepID, "No existing configs to backup")
		return nil
	}

	SendLog(m, stepID, fmt.Sprintf("Backing up %d existing configs...", len(m.ExistingConfigs)))

	backupDir, err := system.CreateBackup(system.OSFileSystem{}, m.SystemInfo.HomeDir, m.ExistingConfigs)
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
	if selected["oh-my-posh"] {
		packages = append(packages, "oh-my-posh")
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
	theme, flavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	m.SelectedTheme, m.SelectedFlavor = theme, flavor
	report := deployReport{}

	plan, err := buildDeployPlan(dotfilesDir, homeDir)
	if err != nil {
		report.recordFailed("deploy plan", err)
		SendLog(m, stepID, fmt.Sprintf("✗ Deploy plan failed: %v", err))
		SendLog(m, stepID, report.summary())
		return err
	}

	for _, target := range plan.Targets {
		SendLog(m, stepID, fmt.Sprintf("Deploying %s...", target.Name))

		if target.IsDir {
			if err := system.CopyDir(target.Source, target.Destination); err != nil {
				report.recordFailed(target.Name, err)
				SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
				continue
			}
			report.recordChanged(target.Name)
			SendLog(m, stepID, fmt.Sprintf("  ✓ %s/", target.Name))
			if err := replaceThemeInDir(target.Destination, theme, flavor, m.SelectedAccent); err != nil {
				report.recordWarning(target.Name+" replace", err)
				SendLog(m, stepID, fmt.Sprintf("  ⚠ Replace failed: %v", err))
			}
			continue
		}

		changed, err := system.CopyFileIfChanged(target.Source, target.Destination)
		if err != nil {
			report.recordFailed(target.Name, err)
			SendLog(m, stepID, fmt.Sprintf("  ✗ Failed: %v", err))
			continue
		}
		if changed {
			report.recordChanged(target.Name)
			SendLog(m, stepID, fmt.Sprintf("  ✓ %s", target.Name))
		} else {
			report.recordSkipped(target.Name)
			SendLog(m, stepID, fmt.Sprintf("  ✓ %s unchanged", target.Name))
		}
		if err := replaceThemeInFile(target.Destination, theme, flavor, m.SelectedAccent); err != nil {
			report.recordWarning(target.Name+" replace", err)
			SendLog(m, stepID, fmt.Sprintf("  ⚠ Replace failed: %v", err))
		}
	}

	// 4.4 Oh My Posh theme
	ohMyPoshSrc := themeAssetPath(dotfilesDir, "oh-my-posh", theme, fmt.Sprintf("%s.json", flavor), fmt.Sprintf("%s.json", flavor))
	ohMyPoshDst := filepath.Join(homeDir, ".config", "oh-my-posh", "config.json")
	if changed, err := system.CopyFileIfChanged(ohMyPoshSrc, ohMyPoshDst); err != nil {
		report.recordWarning("oh-my-posh theme", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Oh My Posh theme failed: %v", err))
	} else if changed {
		report.recordChanged("oh-my-posh theme")
		SendLog(m, stepID, "✓ Oh My Posh theme deployed")
	} else {
		report.recordSkipped("oh-my-posh theme")
		SendLog(m, stepID, "✓ Oh My Posh theme unchanged")
	}

	// 4.5 Atuin theme
	atuinFile := atuinThemeName(theme, flavor, m.SelectedAccent) + ".toml"
	atuinSrc := themeAssetPath(dotfilesDir, "atuin", theme, atuinFile, fmt.Sprintf("catppuccin-%s-%s.toml", flavor, m.SelectedAccent))
	atuinDst := filepath.Join(homeDir, ".config", "atuin", "themes", atuinFile)
	if changed, err := system.CopyFileIfChanged(atuinSrc, atuinDst); err != nil {
		report.recordWarning("atuin theme", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Atuin theme failed: %v", err))
	} else if changed {
		report.recordChanged("atuin theme")
		SendLog(m, stepID, "✓ Atuin theme deployed")
	} else {
		report.recordSkipped("atuin theme")
		SendLog(m, stepID, "✓ Atuin theme unchanged")
	}

	// 4.6 Bottom theme
	bottomSrc := themeAssetPath(dotfilesDir, "bottom", theme, fmt.Sprintf("%s.toml", flavor), fmt.Sprintf("%s.toml", flavor))
	bottomDst := filepath.Join(homeDir, ".config", "bottom", "bottom.toml")
	if changed, err := system.CopyFileIfChanged(bottomSrc, bottomDst); err != nil {
		report.recordWarning("bottom theme", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Bottom theme failed: %v", err))
	} else if changed {
		report.recordChanged("bottom theme")
		SendLog(m, stepID, "✓ Bottom theme deployed")
	} else {
		report.recordSkipped("bottom theme")
		SendLog(m, stepID, "✓ Bottom theme unchanged")
	}

	// 4.7 Lazygit theme
	lazygitSrc := themeAssetPath(dotfilesDir, "lazygit", theme, fmt.Sprintf("%s.yml", flavor), fmt.Sprintf("%s.yml", flavor))
	lazygitDst := filepath.Join(homeDir, ".config", "lazygit", "config.yml")
	if changed, err := system.CopyFileIfChanged(lazygitSrc, lazygitDst); err != nil {
		report.recordWarning("lazygit theme", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Lazygit theme failed: %v", err))
	} else if changed {
		report.recordChanged("lazygit theme")
		SendLog(m, stepID, "✓ Lazygit theme deployed")
	} else {
		report.recordSkipped("lazygit theme")
		SendLog(m, stepID, "✓ Lazygit theme unchanged")
	}

	// 4.8 Bat theme
	batFile := batThemeFile(theme, flavor)
	batSrc := themeAssetPath(dotfilesDir, "bat", theme, batFile, fmt.Sprintf("Catppuccin-%s.tmTheme", flavor))
	batDst := filepath.Join(homeDir, ".config", "bat", "themes", batFile)
	batChanged, err := system.CopyFileIfChanged(batSrc, batDst)
	if err != nil {
		report.recordWarning("bat theme", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Bat theme failed: %v", err))
	} else {
		if batChanged {
			report.recordChanged("bat theme")
			SendLog(m, stepID, "✓ Bat theme deployed")
		} else {
			report.recordSkipped("bat theme")
			SendLog(m, stepID, "✓ Bat theme unchanged")
		}
		batInstalled := system.CommandExists("bat")
		if batChanged && batInstalled {
			result := system.Run("bat cache --build", nil)
			if result.Error != nil {
				report.recordWarning("bat cache", result.Error)
				SendLog(m, stepID, fmt.Sprintf("⚠ Bat cache build failed: %v", result.Error))
			} else {
				report.recordChanged("bat cache")
			}
		} else if !batInstalled {
			report.recordSkipped("bat cache")
			SendLog(m, stepID, "ℹ bat not installed, skipping cache build")
		} else {
			report.recordSkipped("bat cache")
			SendLog(m, stepID, "ℹ Bat theme unchanged, skipping cache build")
		}
	}
	batEnv := fmt.Sprintf(`export BAT_THEME="%s"`, batThemeName(theme, flavor))
	if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_BAT_START", "# CATPPUCCIN_BAT_END", batEnv); err != nil {
		report.recordWarning("BAT_THEME setup", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ BAT_THEME setup failed: %v", err))
	} else {
		report.recordChanged("BAT_THEME setup")
	}

	// 4.9 Eza colors
	ezaSrc := themeAssetPath(dotfilesDir, "eza", theme, fmt.Sprintf("%s.txt", flavor), fmt.Sprintf("%s.txt", flavor))
	if ezaData, err := os.ReadFile(ezaSrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_EZA_START", "# CATPPUCCIN_EZA_END", string(ezaData)); err != nil {
			report.recordWarning("eza colors setup", err)
			SendLog(m, stepID, fmt.Sprintf("⚠ Eza colors setup failed: %v", err))
		} else {
			report.recordChanged("eza colors")
			SendLog(m, stepID, "✓ Eza colors deployed")
		}
	} else {
		report.recordWarning("eza colors read", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Eza colors read failed: %v", err))
	}

	// 4.10 fzf colors
	fzfSrc := themeAssetPath(dotfilesDir, "fzf", theme, fmt.Sprintf("%s.sh", flavor), fmt.Sprintf("%s.sh", flavor))
	if fzfData, err := os.ReadFile(fzfSrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".zshrc"), "# CATPPUCCIN_FZF_START", "# CATPPUCCIN_FZF_END", string(fzfData)); err != nil {
			report.recordWarning("fzf colors setup", err)
			SendLog(m, stepID, fmt.Sprintf("⚠ Fzf colors setup failed: %v", err))
		} else {
			report.recordChanged("fzf colors")
			SendLog(m, stepID, "✓ Fzf colors deployed")
		}
	} else {
		report.recordWarning("fzf colors read", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Fzf colors read failed: %v", err))
	}

	// 4.11 Ghostty theme
	ghosttySrc := themeAssetPath(dotfilesDir, "ghostty", theme, fmt.Sprintf("%s.conf", flavor), fmt.Sprintf("%s.conf", flavor))
	if ghosttyData, err := os.ReadFile(ghosttySrc); err == nil {
		if err := system.ReplaceBetweenMarkers(filepath.Join(homeDir, ".config", "ghostty", "config"), "# CATPPUCCIN_GHOSTTY_THEME_START", "# CATPPUCCIN_GHOSTTY_THEME_END", string(ghosttyData)); err != nil {
			report.recordWarning("ghostty theme setup", err)
			SendLog(m, stepID, fmt.Sprintf("⚠ Ghostty theme setup failed: %v", err))
		} else {
			report.recordChanged("ghostty theme")
			SendLog(m, stepID, "✓ Ghostty theme deployed")
		}
	} else {
		report.recordWarning("ghostty theme read", err)
		SendLog(m, stepID, fmt.Sprintf("⚠ Ghostty theme read failed: %v", err))
	}

	SendLog(m, stepID, "✓ All configs deployed")
	SendLog(m, stepID, report.summary())
	return nil
}

func shouldSkipConfigEntry(name string) bool {
	return name == ".DS_Store"
}

func stepSaveManifest(m *Model) error {
	stepID := "manifest"
	dotfilesDir := m.SystemInfo.DotfilesDir

	theme, flavor := normalizeThemeFlavor(m.SelectedTheme, m.SelectedFlavor)
	if err := system.SaveManifest(system.OSFileSystem{}, dotfilesDir, theme, flavor); err != nil {
		return fmt.Errorf("failed to save manifest: %w", err)
	}

	SendLog(m, stepID, "✓ Manifest saved")
	return nil
}
