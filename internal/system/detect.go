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

func Detect(fs FileSystem) (*SystemInfo, error) {
	home := homeDirFS(fs)
	info := &SystemInfo{
		Arch:           runtime.GOARCH,
		HomeDir:        home,
		UserShell:      os.Getenv("SHELL"),
		InstalledTools: make(map[string]bool),
		ARM:            runtime.GOARCH == "arm64",
	}

	// Check Termux FIRST before standard OS detection
	if isTermuxFS(fs) {
		info.Termux = true
		info.OS = OSLinux
		info.OSName = "Termux (Android)"
	} else {
		switch runtime.GOOS {
		case "darwin":
			info.OS = OSMac
			info.OSName = "macOS"
			info.HasXcode = CommandExists("xcode-select")
		case "linux":
			info.OS = detectLinuxDistroFS(fs)
			info.OSName = linuxDistroName(info.OS)
			if fileExistsFS(fs, "/proc/version") {
				data, err := readFileFS(fs, "/proc/version")
				if err == nil {
					info.IsWSL = strings.Contains(data, "microsoft")
				}
			}
		default:
			info.OS = OSUnknown
			info.OSName = "unknown"
		}
	}

	info.HasBrew = CommandExists("brew")

	tools := []string{"tmux", "nvim", "git", "fzf", "bat", "rg", "fd", "gh", "zoxide", "atuin", "starship", "eza", "lazygit", "mise", "ghostty"}
	for _, tool := range tools {
		info.InstalledTools[tool] = CommandExists(tool)
	}

	info.DotfilesDir = findDotfilesDirFS(fs)

	return info, nil
}

func isTermuxFS(fs FileSystem) bool {
	if os.Getenv("TERMUX_VERSION") != "" {
		return true
	}
	if fileExistsFS(fs, "/data/data/com.termux") {
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

func detectLinuxDistroFS(fs FileSystem) OS {
	if fileExistsFS(fs, "/etc/debian_version") || fileExistsFS(fs, "/etc/apt") {
		return OSDebian
	}
	if fileExistsFS(fs, "/etc/fedora-release") || fileExistsFS(fs, "/etc/dnf") {
		return OSFedora
	}
	if fileExistsFS(fs, "/etc/arch-release") || fileExistsFS(fs, "/etc/pacman.conf") {
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

func homeDirFS(fs FileSystem) string {
	if dir, err := fs.UserHomeDir(); err == nil {
		return dir
	}
	return os.Getenv("HOME")
}

func findDotfilesDirFS(fs FileSystem) string {
	candidates := []string{
		homeDirFS(fs) + "/.dotfiles",
		os.Getenv("DOTFILES_DIR"),
	}
	if wd, err := os.Getwd(); err == nil {
		if _, err := fs.Stat(wd + "/.config"); err == nil {
			candidates = append([]string{wd}, candidates...)
		}
	}
	for _, dir := range candidates {
		if dir != "" {
			if _, err := fs.Stat(dir); err == nil {
				return dir
			}
		}
	}
	return homeDirFS(fs) + "/.dotfiles"
}

// CommandExists checks if a command is available in PATH.
func CommandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func fileExistsFS(fs FileSystem, path string) bool {
	_, err := fs.Stat(path)
	return err == nil
}

func readFileFS(fs FileSystem, path string) (string, error) {
	data, err := fs.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}
