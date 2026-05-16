package tui

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jals/dotfiles/internal/system"
)

func TestBuildDeployPlanIncludesConfigEntriesAndHomeDotfiles(t *testing.T) {
	dotfilesDir := t.TempDir()
	homeDir := t.TempDir()

	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".config", "nvim", "init.lua"), "vim.opt.number = true")
	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".config", "starship.toml"), "format = '$all'")
	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".config", ".DS_Store"), "metadata")
	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".zshrc"), "source ~/.zalias")

	plan, err := buildDeployPlan(dotfilesDir, homeDir)
	if err != nil {
		t.Fatalf("buildDeployPlan() error = %v", err)
	}

	wantNames := []string{".config/nvim", ".config/starship.toml", ".zshrc"}
	if got := planTargetNames(plan); !equalStrings(got, wantNames) {
		t.Fatalf("plan target names = %#v, want %#v", got, wantNames)
	}

	assertDeployTarget(t, plan.Targets[0], ".config/nvim", filepath.Join(dotfilesDir, "home", ".config", "nvim"), filepath.Join(homeDir, ".config", "nvim"), true)
	assertDeployTarget(t, plan.Targets[1], ".config/starship.toml", filepath.Join(dotfilesDir, "home", ".config", "starship.toml"), filepath.Join(homeDir, ".config", "starship.toml"), false)
	assertDeployTarget(t, plan.Targets[2], ".zshrc", filepath.Join(dotfilesDir, "home", ".zshrc"), filepath.Join(homeDir, ".zshrc"), false)
}

func TestBuildDeployPlanHandlesMissingConfigDirectory(t *testing.T) {
	dotfilesDir := t.TempDir()
	homeDir := t.TempDir()
	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".zprofile"), "export ZDOTDIR=$HOME")

	plan, err := buildDeployPlan(dotfilesDir, homeDir)
	if err != nil {
		t.Fatalf("buildDeployPlan() error = %v", err)
	}

	wantNames := []string{".zprofile"}
	if got := planTargetNames(plan); !equalStrings(got, wantNames) {
		t.Fatalf("plan target names = %#v, want %#v", got, wantNames)
	}
}

func TestStepDeployConfigsLogsStructuredSummary(t *testing.T) {
	dotfilesDir := t.TempDir()
	homeDir := t.TempDir()

	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".config", "ghostty", "config"), "# ghostty")
	writeTestFile(t, filepath.Join(dotfilesDir, "home", ".zshrc"), "# zsh")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "oh-my-posh", "catppuccin", "mocha.json"), "{}")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "atuin", "catppuccin", "mocha.toml"), "theme = 'mocha'")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "bottom", "catppuccin", "mocha.toml"), "[colors]")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "lazygit", "catppuccin", "mocha.yml"), "gui: {}")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "bat", "catppuccin", "Catppuccin-mocha.tmTheme"), "<plist />")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "eza", "catppuccin", "mocha.txt"), "export EZA_COLORS=''")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "fzf", "catppuccin", "mocha.sh"), "export FZF_DEFAULT_OPTS=''")
	writeTestFile(t, filepath.Join(dotfilesDir, "assets", "themes", "ghostty", "catppuccin", "mocha.conf"), "palette = 0=#000000")

	model := &Model{
		SystemInfo:     &system.SystemInfo{HomeDir: homeDir, DotfilesDir: dotfilesDir},
		SelectedTheme:  "catppuccin",
		SelectedFlavor: "mocha",
		SelectedAccent: "mauve",
	}

	if err := stepDeployConfigs(model); err != nil {
		t.Fatalf("stepDeployConfigs() error = %v", err)
	}

	logs := strings.Join(model.LogLines, "\n")
	if !strings.Contains(logs, "Deploy summary:") {
		t.Fatalf("deploy logs missing summary:\n%s", logs)
	}
	if !strings.Contains(logs, "failed=0") {
		t.Fatalf("deploy summary should report zero failures:\n%s", logs)
	}
}

func TestDeployReportSummaryCountsOutcomes(t *testing.T) {
	var report deployReport
	report.recordChanged("nvim")
	report.recordChanged("zshrc")
	report.recordSkipped("bat cache")
	report.recordWarning("fzf", assertErr("missing fzf theme"))
	report.recordFailed("ghostty", assertErr("copy failed"))

	if report.Changed != 2 {
		t.Fatalf("Changed = %d, want 2", report.Changed)
	}
	if report.Skipped != 1 {
		t.Fatalf("Skipped = %d, want 1", report.Skipped)
	}
	if report.Warnings != 1 {
		t.Fatalf("Warnings = %d, want 1", report.Warnings)
	}
	if report.Failed != 1 {
		t.Fatalf("Failed = %d, want 1", report.Failed)
	}

	want := "Deploy summary: changed=2 skipped=1 warnings=1 failed=1"
	if got := report.summary(); got != want {
		t.Fatalf("summary() = %q, want %q", got, want)
	}
}

func planTargetNames(plan deployPlan) []string {
	names := make([]string, 0, len(plan.Targets))
	for _, target := range plan.Targets {
		names = append(names, target.Name)
	}
	return names
}

func assertDeployTarget(t *testing.T, target deployTarget, name, source, destination string, isDir bool) {
	t.Helper()
	if target.Name != name {
		t.Fatalf("Name = %q, want %q", target.Name, name)
	}
	if target.Source != source {
		t.Fatalf("Source = %q, want %q", target.Source, source)
	}
	if target.Destination != destination {
		t.Fatalf("Destination = %q, want %q", target.Destination, destination)
	}
	if target.IsDir != isDir {
		t.Fatalf("IsDir = %v, want %v", target.IsDir, isDir)
	}
}

type assertErr string

func (e assertErr) Error() string { return string(e) }

func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("MkdirAll(%q) error = %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("WriteFile(%q) error = %v", path, err)
	}
}

func equalStrings(got, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i] != want[i] {
			return false
		}
	}
	return true
}
