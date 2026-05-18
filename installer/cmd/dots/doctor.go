package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/jals/dotfiles/internal/system"
)

type doctorResult struct {
	Name string
	Err  error
}

func runDoctor(args []string) {
	if help, err := validateNoArgCommand("doctor", args); err != nil {
		fmt.Fprintf(os.Stderr, "Doctor failed: %v\n\n", err)
		printDoctorHelp()
		os.Exit(1)
	} else if help {
		printDoctorHelp()
		return
	}

	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}

	results := runDoctorChecks(system.OSFileSystem{}, info.HomeDir, info.DotfilesDir)
	printDoctorReport(os.Stdout, results)
	if doctorHasFailures(results) {
		os.Exit(1)
	}
}

func runDoctorChecks(fs system.FileSystem, homeDir, dotfilesDir string) []doctorResult {
	_ = dotfilesDir // Reserved for future source/manifest checks; current doctor is deploy-local only.
	checks := []doctorResult{}
	add := func(name string, err error) {
		checks = append(checks, doctorResult{Name: name, Err: err})
	}

	add("shell zshrc", checkFile(fs, filepath.Join(homeDir, ".zshrc")))
	add("shell zprofile", checkFile(fs, filepath.Join(homeDir, ".zprofile")))
	add("shell aliases", checkFile(fs, filepath.Join(homeDir, ".zalias")))
	add("config directory", checkDir(fs, filepath.Join(homeDir, ".config")))
	add("Oh My Posh config", checkFile(fs, filepath.Join(homeDir, ".config", "oh-my-posh", "config.json")))
	add("Neovim init", checkFile(fs, filepath.Join(homeDir, ".config", "nvim", "init.lua")))
	add("Neovim LazyVim config", checkFile(fs, filepath.Join(homeDir, ".config", "nvim", "lua", "config", "lazy.lua")))
	add("Neovim opencode config", checkFile(fs, filepath.Join(homeDir, ".config", "nvim", "lua", "plugins", "opencode.lua")))
	add("tmux config", checkFile(fs, filepath.Join(homeDir, ".config", "tmux", "tmux.conf")))
	add("Ghostty config", checkFile(fs, filepath.Join(homeDir, ".config", "ghostty", "config")))
	add("Ghostty cursor smear shader", checkFile(fs, filepath.Join(homeDir, ".config", "ghostty", "shaders", "cursor_smear.glsl")))
	add("AeroSpace config", checkFile(fs, filepath.Join(homeDir, ".config", "aerospace", "aerospace.toml")))
	add("bat themes directory", checkDir(fs, filepath.Join(homeDir, ".config", "bat", "themes")))

	add("Oh My Posh JSON", checkJSONFile(fs, filepath.Join(homeDir, ".config", "oh-my-posh", "config.json")))
	add("shell prompt and bat theme", checkFileContainsAll(fs, filepath.Join(homeDir, ".zshrc"), []string{
		"oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json",
		"export BAT_THEME=",
	}))
	add("bat theme file", checkAnyFileWithSuffix(fs, filepath.Join(homeDir, ".config", "bat", "themes"), ".tmTheme"))
	add("generated shell markers", checkMarkersOnce(fs, filepath.Join(homeDir, ".zshrc"), []string{
		"# dots:bat-theme begin",
	}))
	add("fzf theme source line", checkFileContainsAll(fs, filepath.Join(homeDir, ".zshrc"), []string{
		"source ~/.config/fzf/theme.sh",
	}))
	add("eza colors source line", checkFileContainsAll(fs, filepath.Join(homeDir, ".zshrc"), []string{
		"source ~/.config/eza/colors.sh",
	}))
	add("fzf theme file", checkFile(fs, filepath.Join(homeDir, ".config", "fzf", "theme.sh")))
	add("eza colors file", checkFile(fs, filepath.Join(homeDir, ".config", "eza", "colors.sh")))
	add("atuin theme file", checkFile(fs, filepath.Join(homeDir, ".config", "atuin", "themes", "dots.toml")))
	add("atuin config theme name", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "atuin", "config.toml"), []string{
		`name = "dots"`,
	}))
	add("Neovim config smoke", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "nvim", "init.lua"), []string{
		`require("config.lazy")`,
		`require("config.nodejs").setup({ silent = true })`,
	}))
	add("Neovim LazyVim smoke", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "nvim", "lua", "config", "lazy.lua"), []string{
		`"LazyVim/LazyVim"`,
	}))
	add("Neovim opencode smoke", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "nvim", "lua", "plugins", "opencode.lua"), []string{
		`"NickvanDyke/opencode.nvim"`,
	}))
	add("tmux config smoke", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "tmux", "tmux.conf"), []string{
		"set -g prefix C-a",
	}))
	add("Ghostty config smoke", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "ghostty", "config"), []string{
		"keybind = alt+s=write_screen_file:paste",
		"theme = dots",
	}))
	add("Ghostty theme file", checkFile(fs, filepath.Join(homeDir, ".config", "ghostty", "themes", "dots")))
	add("AeroSpace resize bindings", checkFileContainsAll(fs, filepath.Join(homeDir, ".config", "aerospace", "aerospace.toml"), []string{
		"ctrl-alt-minus = 'resize smart -50'",
		"ctrl-alt-equal = 'resize smart +50'",
	}))

	return checks
}

func printDoctorReport(w io.Writer, results []doctorResult) {
	p := subcommandPalette()
	failures := 0
	fmt.Fprintln(w, subcommandHeader(p, "doctor"))
	for _, result := range results {
		if result.Err != nil {
			failures++
			fmt.Fprintln(w, subcommandFailRow(p, result.Name, result.Err))
			continue
		}
		fmt.Fprintln(w, subcommandPassRow(p, result.Name))
	}
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, subcommandSummary(p, failures == 0, failures))
}

func doctorHasFailures(results []doctorResult) bool {
	for _, result := range results {
		if result.Err != nil {
			return true
		}
	}
	return false
}

func checkFile(fs system.FileSystem, path string) error {
	info, err := fs.Stat(path)
	if err != nil {
		return err
	}
	if info.IsDir() {
		return fmt.Errorf("%s is a directory", path)
	}
	return nil
}

func checkDir(fs system.FileSystem, path string) error {
	info, err := fs.Stat(path)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("%s is not a directory", path)
	}
	return nil
}

func checkJSONFile(fs system.FileSystem, path string) error {
	data, err := fs.ReadFile(path)
	if err != nil {
		return err
	}
	var value any
	if err := json.Unmarshal(data, &value); err != nil {
		return err
	}
	return nil
}

func checkFileContainsAll(fs system.FileSystem, path string, needles []string) error {
	data, err := fs.ReadFile(path)
	if err != nil {
		return err
	}
	content := string(data)
	missing := []string{}
	for _, needle := range needles {
		if !strings.Contains(content, needle) {
			missing = append(missing, needle)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing %s", strings.Join(missing, ", "))
	}
	return nil
}

func checkAnyFileWithSuffix(fs system.FileSystem, dir, suffix string) error {
	entries, err := fs.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), suffix) {
			return nil
		}
	}
	return fmt.Errorf("no %s file found in %s", suffix, dir)
}

func checkMarkersOnce(fs system.FileSystem, path string, markers []string) error {
	data, err := fs.ReadFile(path)
	if err != nil {
		return err
	}
	content := string(data)
	for _, marker := range markers {
		if count := strings.Count(content, marker); count != 1 {
			return fmt.Errorf("marker %q count=%d, want 1", marker, count)
		}
	}
	return nil
}

func printDoctorHelp() {
	fmt.Println("dots doctor - Validate deployed dotfiles")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  dots doctor")
}
