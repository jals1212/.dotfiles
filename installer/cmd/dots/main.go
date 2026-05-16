package main

import (
	"errors"
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
	case "restore":
		runRestore(os.Args[2:])
	case "reload":
		runReload(os.Args[2:])
	case "help", "-h", "--help":
		printHelp()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		printHelp()
		os.Exit(1)
	}
}

func newTUIProgram(model tui.Model) *tea.Program {
	return tea.NewProgram(model, tea.WithAltScreen())
}

func runTUI() {
	model, err := tui.NewModel()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	p := newTUIProgram(model)
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
	model, err := tui.NewModel()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
	p := newTUIProgram(model)
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runNonInteractiveInstall() {
	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}

	flavor := os.Getenv("DOTS_FLAVOR")
	theme := os.Getenv("DOTS_THEME")
	if theme == "" {
		theme = "kanagawa"
	}
	if flavor == "" {
		flavor = "dragon"
	}

	fmt.Println("Running non-interactive install...")
	fmt.Printf("OS: %s (%s)\n", info.OSName, info.Arch)
	fmt.Printf("Theme: %s/%s\n", theme, flavor)

	// Build model for step execution
	model := &tui.Model{
		SystemInfo:       info,
		IsNonInteractive: true,
		SelectedTheme:    theme,
		SelectedFlavor:   flavor,
		SelectedAccent:   "mauve",
		Tools: []tui.Tool{
			{Name: "ghostty", Selected: true},
			{Name: "tmux", Selected: true},
			{Name: "nvim", Selected: true},
			{Name: "oh-my-posh", Selected: true},
			{Name: "atuin", Selected: true},
			{Name: "zoxide", Selected: true},
			{Name: "zsh", Selected: true},
		},
	}

	// Detect existing configs
	model.ExistingConfigs = system.DetectExistingConfigs(system.OSFileSystem{}, info.DotfilesDir, info.HomeDir)

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
	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Updating dotfiles...")
	fmt.Printf("Dotfiles: %s\n", info.DotfilesDir)

	if err := deployAndSaveManifest(info, envOrDefault("DOTS_THEME", "kanagawa"), envOrDefault("DOTS_FLAVOR", "dragon")); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n✓ Configs updated")
}

func deployAndSaveManifest(info *system.SystemInfo, theme, flavor string) error {
	model := &tui.Model{
		SystemInfo:       info,
		IsNonInteractive: true,
		SelectedTheme:    theme,
		SelectedFlavor:   flavor,
		SelectedAccent:   "mauve",
	}

	if err := tui.ExecuteStep("deploy", model); err != nil {
		return fmt.Errorf("Deploy failed: %v", err)
	}
	if err := tui.ExecuteStep("manifest", model); err != nil {
		return fmt.Errorf("Manifest failed: %v", err)
	}
	return nil
}

func runUninstall() {
	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Uninstalling dotfiles...")

	if err := system.Uninstall(system.OSFileSystem{}, info.DotfilesDir, info.HomeDir); err != nil {
		fmt.Fprintf(os.Stderr, "Uninstall failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Uninstalled. Configs removed. Restore from backup manually if needed.")
}

func runRestore(args []string) {
	if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
		printRestoreHelp()
		return
	}

	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}

	backupDir, err := resolveRestoreBackupPath(system.OSFileSystem{}, info.HomeDir, args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Restore failed: %v\n\n", err)
		printRestoreHelp()
		os.Exit(1)
	}

	fmt.Printf("Restoring dotfiles from %s...\n", backupDir)
	if err := system.RestoreBackup(system.OSFileSystem{}, backupDir, info.HomeDir); err != nil {
		fmt.Fprintf(os.Stderr, "Restore failed: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("✓ Restore complete")
}

func runReload(args []string) {
	if len(args) > 0 && (args[0] == "-h" || args[0] == "--help" || args[0] == "help") {
		printReloadHelp()
		return
	}

	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error detecting system: %v\n", err)
		os.Exit(1)
	}

	force, err := resolveReloadOptions(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Reload failed: %v\n\n", err)
		printReloadHelp()
		os.Exit(1)
	}

	if !force {
		needsReload, currentHash, storedHash, err := system.NeedsReload(system.OSFileSystem{}, info.DotfilesDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Reload failed: %v\n", err)
			os.Exit(1)
		}
		if !needsReload {
			fmt.Printf("Configs already current (source hash %s)\n", currentHash)
			return
		}
		if storedHash == "" {
			fmt.Println("Reload needed: manifest has no source hash")
		} else {
			fmt.Printf("Reload needed: source hash changed (%s -> %s)\n", storedHash, currentHash)
		}
	} else {
		fmt.Println("Force reloading configs...")
	}

	if err := deployAndSaveManifest(info, envOrDefault("DOTS_THEME", "kanagawa"), envOrDefault("DOTS_FLAVOR", "dragon")); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
	fmt.Println("\n✓ Configs reloaded")
}

func resolveReloadOptions(args []string) (bool, error) {
	flags := flag.NewFlagSet("reload", flag.ContinueOnError)
	force := flags.Bool("force", false, "Re-deploy even when source hash is unchanged")
	if err := flags.Parse(args); err != nil {
		return false, err
	}
	if len(flags.Args()) > 0 {
		return false, errors.New("reload does not accept positional arguments")
	}
	return *force, nil
}

func resolveRestoreBackupPath(fs system.FileSystem, homeDir string, args []string) (string, error) {
	flags := flag.NewFlagSet("restore", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	latest := flags.Bool("latest", false, "Restore latest backup")
	if err := flags.Parse(args); err != nil {
		return "", err
	}

	remaining := flags.Args()
	if *latest && len(remaining) > 0 {
		return "", errors.New("use either --latest or a backup directory path, not both")
	}
	if *latest {
		return system.LatestBackup(fs, homeDir)
	}
	if len(remaining) != 1 {
		return "", errors.New("expected --latest or exactly one backup directory path")
	}
	return remaining[0], nil
}

func printHelp() {
	fmt.Println("dots - Dotfiles Manager")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  dots                    Launch interactive TUI installer")
	fmt.Println("  dots install            Install dotfiles (interactive)")
	fmt.Println("  dots install --yes      Install dotfiles (non-interactive)")
	fmt.Println("                          Uses DOTS_THEME/DOTS_FLAVOR, default kanagawa/dragon")
	fmt.Println("  dots update             Re-deploy configs only")
	fmt.Println("  dots reload             Re-deploy only when source configs changed")
	fmt.Println("  dots reload --force     Re-deploy configs regardless of source hash")
	fmt.Println("  dots uninstall          Remove deployed configs")
	fmt.Println("  dots restore --latest   Restore latest backup")
	fmt.Println("  dots restore <dir>      Restore a specific backup directory")
	fmt.Println("  dots help               Show this help")
}

func printReloadHelp() {
	fmt.Println("dots reload - Conditionally re-deploy configs when source files changed")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  dots reload")
	fmt.Println("  dots reload --force")
}

func printRestoreHelp() {
	fmt.Println("dots restore - Restore dotfiles from backup")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  dots restore --latest")
	fmt.Println("  dots restore <backup-dir>")
}

func envOrDefault(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}
