package main

import (
	"bytes"
	"fmt"
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
		"# dots:bat-theme begin",
		"# dots:bat-theme begin",
		"# dots:eza-colors begin",
		"# dots:fzf-theme begin",
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

func TestPrintDoctorReportStyledPassOutput(t *testing.T) {
	results := []doctorResult{
		{Name: "shell zshrc", Err: nil},
		{Name: "tmux config", Err: nil},
	}
	var out bytes.Buffer
	printDoctorReport(&out, results)
	got := out.String()

	if !strings.Contains(got, "dots doctor") {
		t.Errorf("styled header missing 'dots doctor':\n%s", got)
	}
	if !strings.Contains(got, "✓") {
		t.Errorf("pass rows missing '✓' glyph:\n%s", got)
	}
	if !strings.Contains(got, "All doctor checks passed") {
		t.Errorf("summary missing 'All doctor checks passed':\n%s", got)
	}
	if strings.Contains(got, "shader file count") {
		t.Errorf("unexpected 'shader file count' in output:\n%s", got)
	}
}

func TestPrintDoctorReportStyledFailOutput(t *testing.T) {
	results := []doctorResult{
		{Name: "shell zshrc", Err: nil},
		{Name: "tmux config", Err: fmt.Errorf("file not found")},
	}
	var out bytes.Buffer
	printDoctorReport(&out, results)
	got := out.String()

	if !strings.Contains(got, "dots doctor") {
		t.Errorf("styled header missing 'dots doctor':\n%s", got)
	}
	if !strings.Contains(got, "✗") {
		t.Errorf("fail row missing '✗' glyph:\n%s", got)
	}
	if !strings.Contains(got, "Doctor found") {
		t.Errorf("summary missing 'Doctor found':\n%s", got)
	}
}

func TestDoctorChecksNoShaderPolicyRow(t *testing.T) {
	homeDir := t.TempDir()
	dotfilesDir := t.TempDir()
	writeDoctorFixture(t, homeDir)
	// Add extra shader files; the old policy check would fail here.
	writeTestFile(t, filepath.Join(homeDir, ".config", "ghostty", "shaders", "extra_shader.glsl"), "void main(){}")

	results := runDoctorChecks(system.OSFileSystem{}, homeDir, dotfilesDir)
	for _, r := range results {
		if r.Name == "Ghostty shader policy" {
			t.Errorf("unexpected 'Ghostty shader policy' check still present")
		}
		if r.Err != nil && strings.Contains(r.Err.Error(), "shader file count") {
			t.Errorf("unexpected 'shader file count' error: %v", r.Err)
		}
	}
	// cursor smear shader check should still pass
	found := false
	for _, r := range results {
		if r.Name == "Ghostty cursor smear shader" {
			found = true
			if r.Err != nil {
				t.Errorf("Ghostty cursor smear shader check failed: %v", r.Err)
			}
		}
	}
	if !found {
		t.Error("Ghostty cursor smear shader check not found in results")
	}
}

func writeDoctorFixture(t *testing.T, homeDir string) {
	t.Helper()
	writeTestFile(t, filepath.Join(homeDir, ".zshrc"), strings.Join([]string{
		`eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json)"`,
		`export BAT_THEME="Kanagawa Dragon"`,
		"# dots:bat-theme begin",
		"# dots:eza-colors begin",
		"# dots:fzf-theme begin",
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
		"theme = dots",
	}, "\n"))
	writeTestFile(t, filepath.Join(homeDir, ".config", "ghostty", "themes", "dots"), "background = 181616\nforeground = c5c9c5\n")
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
