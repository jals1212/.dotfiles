package tui

import (
	"fmt"
	"os"
	"path/filepath"
)

var deployHomeFiles = []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}

type deployPlan struct {
	Targets []deployTarget
}

type deployTarget struct {
	Name        string
	Source      string
	Destination string
	IsDir       bool
}

type deployReport struct {
	Changed  int
	Skipped  int
	Warnings int
	Failed   int
}

func buildDeployPlan(dotfilesDir, homeDir string) (deployPlan, error) {
	plan := deployPlan{}

	configSource := filepath.Join(dotfilesDir, "home", ".config")
	entries, err := os.ReadDir(configSource)
	if err != nil && !os.IsNotExist(err) {
		return plan, fmt.Errorf("read config source: %w", err)
	}
	if err == nil {
		for _, entry := range entries {
			if shouldSkipConfigEntry(entry.Name()) {
				continue
			}
			plan.Targets = append(plan.Targets, deployTarget{
				Name:        filepath.Join(".config", entry.Name()),
				Source:      filepath.Join(configSource, entry.Name()),
				Destination: filepath.Join(homeDir, ".config", entry.Name()),
				IsDir:       entry.IsDir(),
			})
		}
	}

	for _, name := range deployHomeFiles {
		source := filepath.Join(dotfilesDir, "home", name)
		info, err := os.Stat(source)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return plan, fmt.Errorf("stat home file %s: %w", name, err)
		}
		plan.Targets = append(plan.Targets, deployTarget{
			Name:        name,
			Source:      source,
			Destination: filepath.Join(homeDir, name),
			IsDir:       info.IsDir(),
		})
	}

	return plan, nil
}

func (r *deployReport) recordChanged(_ string) {
	r.Changed++
}

func (r *deployReport) recordSkipped(_ string) {
	r.Skipped++
}

func (r *deployReport) recordWarning(_ string, _ error) {
	r.Warnings++
}

func (r *deployReport) recordFailed(_ string, _ error) {
	r.Failed++
}

func (r deployReport) summary() string {
	return fmt.Sprintf("Deploy summary: changed=%d skipped=%d warnings=%d failed=%d", r.Changed, r.Skipped, r.Warnings, r.Failed)
}
