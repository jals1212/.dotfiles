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
	OS             OS
	OSName         string
	Arch           string
	HasBrew        bool
	HasXcode       bool
	IsWSL          bool
	Termux         bool
	ARM            bool
	UserShell      string
	HomeDir        string
	DotfilesDir    string
	InstalledTools map[string]bool
}

func Detect() (*SystemInfo, error) {
	info := &SystemInfo{
		Arch:           runtime.GOARCH,
		HomeDir:        homeDir(),
		UserShell:      os.Getenv("SHELL"),
		InstalledTools: make(map[string]bool),
		ARM:            runtime.GOARCH == "arm64",
	}

	// Check Termux FIRST before standard OS detection
	if isTermux() {
		info.Termux = true
		info.OS = OSLinux
		info.OSName = "Termux (Android)"
	} else {
		switch runtime.GOOS {
		case "darwin":
			info.OS = OSMac
			info.OSName = "macOS"
			info.HasXcode = commandExists("xcode-select")
		case "linux":
			info.OS = detectLinuxDistro()
			info.OSName = linuxDistroName(info.OS)
			if fileExists("/proc/version") {
				data, err := readFile("/proc/version")
				if err == nil {
					info.IsWSL = strings.Contains(data, "microsoft")
				}
			}
		default:
			info.OS = OSUnknown
			info.OSName = "unknown"
		}
	}

	info.HasBrew = commandExists("brew")

	tools := []string{"tmux", "nvim", "git", "fzf", "bat", "rg", "fd", "gh", "zoxide", "atuin", "starship", "eza", "lazygit", "mise", "ghostty"}
	for _, tool := range tools {
		info.InstalledTools[tool] = commandExists(tool)
	}

	info.DotfilesDir = findDotfilesDir()

	return info, nil
}

func isTermux() bool {
	if os.Getenv("TERMUX_VERSION") != "" {
		return true
	}
	if fileExists("/data/data/com.termux") {
		return true
	}
	prefix := os.Getenv("PREFIX")
	if prefix != "" && strings.Contains(prefix, "com.termux") {
		return true
	}
	return false
}

func (s *SystemInfo) IsTermux() bool {
	return s.Termux
}

func (s *SystemInfo) IsARM() bool {
	return s.ARM
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
		OSDebian: "Debian/Ubuntu",
		OSFedora: "Fedora/RHEL",
		OSArch:   "Arch Linux",
		OSLinux:  "Linux",
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

func readFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
