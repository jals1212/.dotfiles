package tui

import (
	"fmt"
	"os"

	"github.com/jals/dotfiles/internal/system"
)

// RunNonInteractive executes the full install sequence without a Bubble Tea
// program. It reads DOTS_THEME and DOTS_FLAVOR from the environment (defaulting
// to kanagawa/dragon) and runs every install step in order, printing progress
// to stdout. On the first step failure it prints to stderr and exits 1.
func RunNonInteractive() {
	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}

	theme := envOrDefaultTUI("DOTS_THEME", "kanagawa")
	flavor := envOrDefaultTUI("DOTS_FLAVOR", "dragon")

	fmt.Println("Running non-interactive install...")
	fmt.Printf("OS: %s (%s)\n", info.OSName, info.Arch)
	fmt.Printf("Theme: %s/%s\n", theme, flavor)

	model := &Model{
		SystemInfo:       info,
		IsNonInteractive: true,
		SelectedTheme:    theme,
		SelectedFlavor:   flavor,
		SelectedAccent:   "mauve",
		Tools: []Tool{
			{Name: "ghostty", Selected: true},
			{Name: "tmux", Selected: true},
			{Name: "nvim", Selected: true},
			{Name: "oh-my-posh", Selected: true},
			{Name: "atuin", Selected: true},
			{Name: "zoxide", Selected: true},
			{Name: "zsh", Selected: true},
		},
	}

	model.ExistingConfigs = system.DetectExistingConfigs(system.OSFileSystem{}, info.DotfilesDir, info.HomeDir)

	steps := []InstallStep{
		{ID: "backup", Name: "Backup existing configs"},
		{ID: "packages", Name: "Install packages"},
		{ID: "deploy", Name: "Deploy configs"},
		{ID: "manifest", Name: "Save manifest"},
	}
	model.Steps = steps

	for _, step := range steps {
		if err := ExecuteStep(step.ID, model); err != nil {
			fmt.Fprintf(os.Stderr, "\n✗ Step '%s' failed: %v\n", step.Name, err)
			os.Exit(1)
		}
	}

	fmt.Println("\n✓ Installation complete!")
	fmt.Println("Restart your shell: exec zsh")
}

// envOrDefaultTUI returns the value of key from the environment, or fallback
// if the variable is unset or empty. This is a package-local copy so that
// non_interactive.go has no import dependency on cmd/dots/main.go.
func envOrDefaultTUI(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}
