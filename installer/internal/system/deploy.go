package system

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ReplaceInFile reads a file, replaces all occurrences of old with new, and writes it back.
func ReplaceInFile(path, old, new string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	content := strings.ReplaceAll(string(data), old, new)
	return os.WriteFile(path, []byte(content), 0644)
}

// ReplaceBetweenMarkers replaces content between startMarker and endMarker in a file.
// If markers don't exist, appends the content with markers at the end of the file.
func ReplaceBetweenMarkers(path, startMarker, endMarker, content string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			data = []byte{}
		} else {
			return err
		}
	}
	text := string(data)
	startIdx := strings.Index(text, startMarker)
	endIdx := strings.Index(text, endMarker)
	if startIdx != -1 && endIdx != -1 && endIdx > startIdx {
		newText := text[:startIdx+len(startMarker)] + "\n" + content + "\n" + text[endIdx:]
		return os.WriteFile(path, []byte(newText), 0644)
	}
	// Append at end
	var b strings.Builder
	if len(text) > 0 && !strings.HasSuffix(text, "\n") {
		b.WriteString("\n")
	}
	b.WriteString(startMarker)
	b.WriteString("\n")
	b.WriteString(content)
	b.WriteString("\n")
	b.WriteString(endMarker)
	b.WriteString("\n")
	return os.WriteFile(path, []byte(text+b.String()), 0644)
}

// CopyFile copies a file from src to dst, preserving permissions
func CopyFile(src, dst string) error {
	info, err := os.Stat(src)
	if err != nil {
		return err
	}

	// Create parent directory
	if err := EnsureDir(filepath.Dir(dst)); err != nil {
		return err
	}

	// If dst exists and is a directory, remove it
	if dstInfo, err := os.Stat(dst); err == nil && dstInfo.IsDir() {
		if err := os.RemoveAll(dst); err != nil {
			return err
		}
	}

	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}

	return os.WriteFile(dst, data, info.Mode())
}

// CopyDir recursively copies a directory from src to dst
func CopyDir(src, dst string) error {
	info, err := os.Stat(src)
	if err != nil {
		return err
	}

	if err := EnsureDir(dst); err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())

		if entry.IsDir() {
			if err := CopyDir(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := CopyFile(srcPath, dstPath); err != nil {
				return err
			}
		}
	}

	// Preserve permissions on the root directory
	return os.Chmod(dst, info.Mode())
}

// EnsureDir creates a directory if it doesn't exist
func EnsureDir(path string) error {
	return os.MkdirAll(path, 0755)
}

// copyFileFS copies a file using the provided FileSystem.
func copyFileFS(fs FileSystem, src, dst string) error {
	info, err := fs.Stat(src)
	if err != nil {
		return err
	}
	if err := fs.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}
	data, err := fs.ReadFile(src)
	if err != nil {
		return err
	}
	return fs.WriteFile(dst, data, info.Mode())
}

// copyDirFS recursively copies a directory using the provided FileSystem.
func copyDirFS(fs FileSystem, src, dst string) error {
	if err := fs.MkdirAll(dst, 0755); err != nil {
		return err
	}
	entries, err := fs.ReadDir(src)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		if entry.IsDir() {
			if err := copyDirFS(fs, srcPath, dstPath); err != nil {
				return err
			}
		} else {
			if err := copyFileFS(fs, srcPath, dstPath); err != nil {
				return err
			}
		}
	}
	return nil
}

// CreateBackup backs up existing config files
func CreateBackup(fs FileSystem, homeDir string, configKeys []string) (string, error) {
	backupDir := filepath.Join(homeDir, ".dotfiles_backups", time.Now().Format("2006-01-02_150405"))

	if err := fs.MkdirAll(backupDir, 0755); err != nil {
		return "", err
	}

	for _, key := range configKeys {
		src := filepath.Join(homeDir, key)
		if _, err := fs.Stat(src); err == nil {
			dst := filepath.Join(backupDir, filepath.Base(key))
			if info, err := fs.Stat(src); err == nil && info.IsDir() {
				if err := copyDirFS(fs, src, dst); err != nil {
					return "", err
				}
			} else {
				if err := copyFileFS(fs, src, dst); err != nil {
					return "", err
				}
			}
		}
	}

	return backupDir, nil
}

// DetectExistingConfigs checks which configs already exist in the target locations
func DetectExistingConfigs(fs FileSystem, dotfilesDir, homeDir string) []string {
	existing := []string{}

	// Check .config entries
	configSource := filepath.Join(dotfilesDir, "home", ".config")
	if entries, err := fs.ReadDir(configSource); err == nil {
		for _, entry := range entries {
			target := filepath.Join(homeDir, ".config", entry.Name())
			if _, err := fs.Stat(target); err == nil {
				existing = append(existing, filepath.Join(".config", entry.Name()))
			}
		}
	}

	// Check home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		src := filepath.Join(dotfilesDir, "home", f)
		if _, err := fs.Stat(src); err == nil {
			target := filepath.Join(homeDir, f)
			if _, err := fs.Stat(target); err == nil {
				existing = append(existing, f)
			}
		}
	}

	return existing
}

// Uninstall removes all deployed configs
func Uninstall(fs FileSystem, dotfilesDir, homeDir string) error {
	// Remove .config entries
	configSource := filepath.Join(dotfilesDir, "home", ".config")
	if entries, err := fs.ReadDir(configSource); err == nil {
		for _, entry := range entries {
			target := filepath.Join(homeDir, ".config", entry.Name())
			if err := fs.RemoveAll(target); err != nil {
				return err
			}
		}
	}

	// Remove home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		target := filepath.Join(homeDir, f)
		if err := fs.Remove(target); err != nil && !os.IsNotExist(err) {
			return err
		}
	}

	// Remove manifest
	manifestPath := filepath.Join(dotfilesDir, "manifest.json")
	if err := fs.Remove(manifestPath); err != nil && !os.IsNotExist(err) {
		return err
	}

	return nil
}

// Manifest records deployment metadata.
type Manifest struct {
	DeployedAt string `json:"deployed_at"`
	Version    string `json:"version"`
	Theme      string `json:"theme"`
	Flavor     string `json:"flavor"`
}

// SaveManifest writes a simple deployment manifest
func SaveManifest(fs FileSystem, dotfilesDir, theme, flavor string) error {
	if theme == "" {
		theme = "kanagawa"
	}
	if flavor == "" {
		flavor = "dragon"
	}
	manifest := Manifest{
		DeployedAt: time.Now().Format(time.RFC3339),
		Version:    "1.0.0",
		Theme:      theme,
		Flavor:     flavor,
	}

	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}

	return fs.WriteFile(filepath.Join(dotfilesDir, "manifest.json"), data, 0644)
}
