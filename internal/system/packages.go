package system

import (
	"fmt"
	"os"
	"os/exec"
)

type PackageSpec struct {
	Name      string
	BrewCask  bool
	AptName   string
	DnfName   string
	PacmanName string
}

func RequiredPackages() []PackageSpec {
	return []PackageSpec{
		{Name: "git"},
		{Name: "tmux"},
		{Name: "neovim", AptName: "neovim", DnfName: "neovim"},
		{Name: "fzf"},
		{Name: "bat"},
		{Name: "ripgrep"},
		{Name: "fd", AptName: "fd-find"},
		{Name: "hub"},
		{Name: "zoxide"},
		{Name: "mise"},
		{Name: "eza", AptName: "eza"},
		{Name: "atuin"},
		{Name: "starship"},
		{Name: "lazygit"},
		{Name: "bottom", AptName: "bottom", DnfName: "bottom"},
		{Name: "dust", AptName: "dust"},
		{Name: "font-iosevka-term-nerd-font", BrewCask: true},
		{Name: "ghostty", BrewCask: true},
	}
}

func Install(spec PackageSpec, info *SystemInfo) error {
	pkgMgr := info.PackageManager()

	switch pkgMgr {
	case "brew":
		return brewInstall(spec)
	case "apt":
		return aptInstall(spec)
	case "dnf":
		return dnfInstall(spec)
	case "pacman":
		return pacmanInstall(spec)
	default:
		return fmt.Errorf("unknown package manager")
	}
}

func IsInstalled(name string) bool {
	return CommandExists(name)
}

func brewInstall(spec PackageSpec) error {
	if spec.BrewCask {
		return run("brew", "install", "--cask", spec.Name)
	}
	return run("brew", "install", spec.Name)
}

func aptInstall(spec PackageSpec) error {
	name := spec.Name
	if spec.AptName != "" {
		name = spec.AptName
	}
	return run("sudo", "apt-get", "install", "-y", name)
}

func dnfInstall(spec PackageSpec) error {
	name := spec.Name
	if spec.DnfName != "" {
		name = spec.DnfName
	}
	return run("sudo", "dnf", "install", "-y", name)
}

func pacmanInstall(spec PackageSpec) error {
	name := spec.Name
	if spec.PacmanName != "" {
		name = spec.PacmanName
	}
	return run("sudo", "pacman", "-S", "--noconfirm", name)
}

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}



