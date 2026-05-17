package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jals/dotfiles/internal/system"
)

func TestRunDoctorChecksPassesForInstalledTree(t *testing.T) {
	homeDir := t.TempDir()
	dotfilesDir := t.TempDir()
	writeDoctorFixture(t, homeDir)

	results := runDoctorChecks(system.OSFileSystem{}, homeDir, dotfilesDir)
	if doctorHasFailures(results) {
		t.Fatalf("runDoctorChecks() had failures:\n%s", doctorResultDebug(results))
	}

	var out bytes.Buffer
	printDoctorReport(&out, results)
	if !strings.Contains(out.String(), "All doctor checks passed") {
		t.Fatalf("doctor report missing success summary:\n%s", out.String())
	}
}

func TestRunDoctorChecksReportsMissingAndInvalidConfig(t *testing.T) {
	homeDir := t.TempDir()
	dotfilesDir := t.TempDir()
	writeDoctorFixture(t, homeDir)
	writeTestFile(t, filepath.Join(homeDir, ".config", "oh-my-posh", "config.json"), "{not-json")
	if err := (system.OSFileSystem{}).Remove(filepath.Join(homeDir, ".config", "tmux", "tmux.conf")); err != nil {
		t.Fatal(err)
	}

	results := runDoctorChecks(system.OSFileSystem{}, homeDir, dotfilesDir)
	if !doctorHasFailures(results) {
		t.Fatal("runDoctorChecks() should fail with invalid JSON and missing tmux config")
	}
	debug := doctorResultDebug(results)
	if !strings.Contains(debug, "Oh My Posh JSON") {
		t.Fatalf("expected Oh My Posh JSON failure, got:\n%s", debug)
	}
	if !strings.Contains(debug, "tmux config") {
		t.Fatalf("expected tmux config failure, got:\n%s", debug)
	}
}

func TestRunDoctorChecksReportsDuplicatedMarkers(t *testing.T) {
	homeDir := t.TempDir()
	dotfilesDir := t.TempDir()
	writeDoctorFixture(t, homeDir)
	writeTestFile(t, filepath.Join(homeDir, ".zshrc"), strings.Join([]string{
		`eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json)"`,
		`export BAT_THEME="Kanagawa Dragon"`,
		"# dots:catppuccin-bat begin",
		"# dots:catppuccin-bat begin",
		"# dots:catppuccin-eza begin",
		"# dots:catppuccin-fzf begin",
	}, "\n"))

	results := runDoctorChecks(system.OSFileSystem{}, homeDir, dotfilesDir)
	if !doctorHasFailures(results) {
		t.Fatal("runDoctorChecks() should fail with duplicated marker")
	}
	if debug := doctorResultDebug(results); !strings.Contains(debug, "generated shell markers") {
		t.Fatalf("expected generated shell markers failure, got:\n%s", debug)
	}
}

func TestValidateNoArgCommandSupportsDoctorHelp(t *testing.T) {
	help, err := validateNoArgCommand("doctor", []string{"--help"})
	if err != nil {
		t.Fatalf("validateNoArgCommand() error = %v", err)
	}
	if !help {
		t.Fatal("validateNoArgCommand() help = false, want true")
	}
}

func writeDoctorFixture(t *testing.T, homeDir string) {
	t.Helper()
	writeTestFile(t, filepath.Join(homeDir, ".zshrc"), strings.Join([]string{
		`eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json)"`,
		`export BAT_THEME="Kanagawa Dragon"`,
		"# dots:catppuccin-bat begin",
		"# dots:catppuccin-eza begin",
		"# dots:catppuccin-fzf begin",
	}, "\n"))
	writeTestFile(t, filepath.Join(homeDir, ".zprofile"), "source ~/.zshrc")
	writeTestFile(t, filepath.Join(homeDir, ".zalias"), "alias ll='eza -la'")
	writeTestFile(t, filepath.Join(homeDir, ".config", "oh-my-posh", "config.json"), `{"version": 3}`)
	writeTestFile(t, filepath.Join(homeDir, ".config", "nvim", "init.lua"), `require("config.lazy")\nrequire("config.nodejs").setup({ silent = true })`)
	writeTestFile(t, filepath.Join(homeDir, ".config", "nvim", "lua", "config", "lazy.lua"), `"LazyVim/LazyVim"`)
	writeTestFile(t, filepath.Join(homeDir, ".config", "nvim", "lua", "plugins", "opencode.lua"), `"NickvanDyke/opencode.nvim"`)
	writeTestFile(t, filepath.Join(homeDir, ".config", "tmux", "tmux.conf"), "set -g prefix C-a")
	writeTestFile(t, filepath.Join(homeDir, ".config", "ghostty", "config"), strings.Join([]string{
		"keybind = alt+s=write_screen_file:paste",
		"# dots:catppuccin-ghostty-theme begin",
	}, "\n"))
	writeTestFile(t, filepath.Join(homeDir, ".config", "ghostty", "shaders", "cursor_smear.glsl"), "void mainImage(){}")
	writeTestFile(t, filepath.Join(homeDir, ".config", "bat", "themes", "Kanagawa-dragon.tmTheme"), "theme")
	writeTestFile(t, filepath.Join(homeDir, ".config", "aerospace", "aerospace.toml"), strings.Join([]string{
		"ctrl-alt-minus = 'resize smart -50'",
		"ctrl-alt-equal = 'resize smart +50'",
	}, "\n"))
}

func doctorResultDebug(results []doctorResult) string {
	var b strings.Builder
	for _, result := range results {
		if result.Err != nil {
			b.WriteString(result.Name)
			b.WriteString(": ")
			b.WriteString(result.Err.Error())
			b.WriteString("\n")
		}
	}
	return b.String()
}

func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("MkdirAll(%q) error = %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("WriteFile(%q) error = %v", path, err)
	}
}
