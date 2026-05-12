package system

import (
	"os"
	"os/exec"
	"runtime"
	"strings"
)

type OS int

const (
	OSMac OS = iota
	OSLinux
	OSDebian
	OSFedora
	OSArch
	OSUnknown
)

type SystemInfo struct {
	OS            OS
	OSName        string
	Arch          string
	HasBrew       bool
	HasXcode      bool
	IsWSL         bool
	UserShell     string
	HomeDir       string
	DotfilesDir   string
	InstalledTools map[string]bool
}

func Detect() *SystemInfo {
	info := &SystemInfo{
		Arch:        runtime.GOARCH,
		HomeDir:     homeDir(),
		UserShell:   os.Getenv("SHELL"),
		InstalledTools: make(map[string]bool),
	}

	switch runtime.GOOS {
	case "darwin":
		info.OS = OSMac
		info.OSName = "macOS"
		info.HasXcode = commandExists("xcode-select")
	case "linux":
		info.OS = detectLinuxDistro()
		info.OSName = linuxDistroName(info.OS)
		info.IsWSL = fileExists("/proc/version") && strings.Contains(readFile("/proc/version"), "microsoft")
	default:
		info.OS = OSUnknown
		info.OSName = "unknown"
	}

	info.HasBrew = commandExists("brew")

	tools := []string{"tmux", "nvim", "git", "fzf", "bat", "rg", "fd", "gh", "zoxide", "atuin", "starship", "eza", "lazygit", "mise", "ghostty"}
	for _, tool := range tools {
		info.InstalledTools[tool] = commandExists(tool)
	}

	info.DotfilesDir = findDotfilesDir()

	return info
}

func detectLinuxDistro() OS {
	if fileExists("/etc/debian_version") || fileExists("/etc/apt") {
		return OSDebian
	}
	if fileExists("/etc/fedora-release") || fileExists("/etc/dnf") {
		return OSFedora
	}
	if fileExists("/etc/arch-release") || fileExists("/etc/pacman.conf") {
		return OSArch
	}
	return OSLinux
}

func linuxDistroName(os OS) string {
	names := map[OS]string{
		OSDebian:  "Debian/Ubuntu",
		OSFedora:  "Fedora/RHEL",
		OSArch:    "Arch Linux",
		OSLinux:   "Linux",
	}
	if name, ok := names[os]; ok {
		return name
	}
	return "Linux"
}

func (s *SystemInfo) IsMac() bool {
	return s.OS == OSMac
}

func (s *SystemInfo) IsLinux() bool {
	return s.OS >= OSLinux
}

func (s *SystemInfo) PackageManager() string {
	if s.HasBrew {
		return "brew"
	}
	switch s.OS {
	case OSDebian:
		return "apt"
	case OSFedora:
		return "dnf"
	case OSArch:
		return "pacman"
	default:
		return "unknown"
	}
}

func homeDir() string {
	if dir, err := os.UserHomeDir(); err == nil {
		return dir
	}
	return os.Getenv("HOME")
}

func findDotfilesDir() string {
	candidates := []string{
		homeDir() + "/.dotfiles",
		os.Getenv("DOTFILES_DIR"),
	}
	if wd, err := os.Getwd(); err == nil {
		if _, err := os.Stat(wd + "/.config"); err == nil {
			candidates = append([]string{wd}, candidates...)
		}
	}
	for _, dir := range candidates {
		if dir != "" {
			if _, err := os.Stat(dir); err == nil {
				return dir
			}
		}
	}
	return homeDir() + "/.dotfiles"
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func readFile(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}