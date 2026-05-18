package system

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Shell identifies the user's interactive shell.
type Shell int

const (
	ShellZsh Shell = iota
	ShellBash
	ShellFish
	ShellUnknown
)

// DetectShell returns the shell identified by the SHELL environment variable.
func DetectShell() Shell {
	s := os.Getenv("SHELL")
	switch {
	case strings.HasSuffix(s, "zsh"):
		return ShellZsh
	case strings.HasSuffix(s, "bash"):
		return ShellBash
	case strings.HasSuffix(s, "fish"):
		return ShellFish
	default:
		return ShellUnknown
	}
}

// RCFile returns the primary rc file path for the given shell on the current OS.
// homeDir must be an absolute path to the user's home directory.
func RCFile(sh Shell, homeDir string) string {
	switch sh {
	case ShellZsh:
		// This repo ships ZDOTDIR=$HOME/.config/zsh; .zshrc lives there.
		return filepath.Join(homeDir, ".config", "zsh", ".zshrc")
	case ShellBash:
		// macOS uses .bash_profile; Linux uses .bashrc.
		if isMacOS() {
			return filepath.Join(homeDir, ".bash_profile")
		}
		return filepath.Join(homeDir, ".bashrc")
	case ShellFish:
		return filepath.Join(homeDir, ".config", "fish", "config.fish")
	default:
		return filepath.Join(homeDir, ".profile")
	}
}

// AppendLineIfMissing appends line to the file at rc if the file does not
// already contain that exact line. The operation is idempotent: calling it
// twice with the same arguments leaves exactly one copy of line in the file.
func AppendLineIfMissing(rc, line string) error {
	data, err := os.ReadFile(rc)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("shell: read %s: %w", rc, err)
	}

	if containsLine(string(data), line) {
		return nil
	}

	f, err := os.OpenFile(rc, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("shell: open %s: %w", rc, err)
	}
	defer f.Close()

	prefix := ""
	if len(data) > 0 && !strings.HasSuffix(string(data), "\n") {
		prefix = "\n"
	}
	_, err = fmt.Fprintf(f, "%s%s\n", prefix, line)
	if err != nil {
		return fmt.Errorf("shell: write %s: %w", rc, err)
	}
	return nil
}

// RemoveLineIfPresent removes every occurrence of line from the file at rc.
// The operation is idempotent.
func RemoveLineIfPresent(rc, line string) error {
	data, err := os.ReadFile(rc)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("shell: read %s: %w", rc, err)
	}

	original := string(data)
	if !containsLine(original, line) {
		return nil
	}

	var out strings.Builder
	scanner := bufio.NewScanner(strings.NewReader(original))
	for scanner.Scan() {
		if scanner.Text() != line {
			out.WriteString(scanner.Text())
			out.WriteByte('\n')
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("shell: scan %s: %w", rc, err)
	}

	return os.WriteFile(rc, []byte(out.String()), 0644)
}

// containsLine reports whether text contains line as a whole line.
func containsLine(text, line string) bool {
	scanner := bufio.NewScanner(strings.NewReader(text))
	for scanner.Scan() {
		if scanner.Text() == line {
			return true
		}
	}
	return false
}

// isMacOS reports whether the current runtime OS is macOS.
func isMacOS() bool {
	_, err := os.Stat("/System/Library/CoreServices")
	return err == nil
}
