package main

import (
	"flag"
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
	"github.com/jals/dotfiles/internal/tui"
)

func main() {
	if len(os.Args) < 2 {
		// Default: run TUI install
		runTUI()
		return
	}

	switch os.Args[1] {
	case "install":
		runInstall(os.Args[2:])
	case "update":
		runUpdate()
	case "uninstall":
		runUninstall()
	case "help", "-h", "--help":
		printHelp()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		printHelp()
		os.Exit(1)
	}
}

func runTUI() {
	model := tui.NewModel()
	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runInstall(args []string) {
	fs := flag.NewFlagSet("install", flag.ExitOnError)
	yes := fs.Bool("yes", false, "Non-interactive mode")
	fs.Parse(args)

	if *yes {
		runNonInteractiveInstall()
		return
	}

	// Interactive TUI install
	model := tui.NewModel()
	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runNonInteractiveInstall() {
	info := system.Detect()
	fmt.Println("Running non-interactive install...")
	fmt.Printf("OS: %s (%s)\n", info.OSName, info.Arch)

	// Build model for step execution
	model := &tui.Model{
		SystemInfo:       info,
		IsNonInteractive: true,
		Tools: []tui.Tool{
			{Name: "ghostty", Selected: true},
			{Name: "tmux", Selected: true},
			{Name: "nvim", Selected: true},
			{Name: "starship", Selected: true},
			{Name: "atuin", Selected: true},
			{Name: "zoxide", Selected: true},
			{Name: "zsh", Selected: true},
		},
	}

	// Detect existing configs
	model.ExistingConfigs = system.DetectExistingConfigs(info.DotfilesDir, info.HomeDir)

	steps := []tui.InstallStep{
		{ID: "backup", Name: "Backup existing configs"},
		{ID: "packages", Name: "Install packages"},
		{ID: "deploy", Name: "Deploy configs"},
		{ID: "manifest", Name: "Save manifest"},
	}
	model.Steps = steps

	for _, step := range steps {
		if err := tui.ExecuteStep(step.ID, model); err != nil {
			fmt.Fprintf(os.Stderr, "\n✗ Step '%s' failed: %v\n", step.Name, err)
			os.Exit(1)
		}
	}

	fmt.Println("\n✓ Installation complete!")
	fmt.Println("Restart your shell: exec zsh")
}

func runUpdate() {
	info := system.Detect()
	fmt.Println("Updating dotfiles...")
	fmt.Printf("Dotfiles: %s\n", info.DotfilesDir)

	// Re-deploy configs using the same step function
	model := &tui.Model{
		SystemInfo:       info,
		IsNonInteractive: true,
	}

	if err := tui.ExecuteStep("deploy", model); err != nil {
		fmt.Fprintf(os.Stderr, "Deploy failed: %v\n", err)
		os.Exit(1)
	}
	if err := tui.ExecuteStep("manifest", model); err != nil {
		fmt.Fprintf(os.Stderr, "Manifest failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n✓ Configs updated")
}

func runUninstall() {
	info := system.Detect()
	fmt.Println("Uninstalling dotfiles...")

	if err := system.Uninstall(info.DotfilesDir, info.HomeDir); err != nil {
		fmt.Fprintf(os.Stderr, "Uninstall failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Uninstalled. Configs removed. Restore from backup manually if needed.")
}

func printHelp() {
	fmt.Println("dots - Dotfiles Manager")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  dots                    Launch interactive TUI installer")
	fmt.Println("  dots install            Install dotfiles (interactive)")
	fmt.Println("  dots install --yes      Install dotfiles (non-interactive)")
	fmt.Println("  dots update             Re-deploy configs only")
	fmt.Println("  dots uninstall          Remove deployed configs")
	fmt.Println("  dots help               Show this help")
}
