package system

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

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
		os.RemoveAll(dst)
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

// CreateBackup backs up existing config files
func CreateBackup(configKeys []string) (string, error) {
	homeDir, _ := os.UserHomeDir()
	backupDir := filepath.Join(homeDir, ".dotfiles_backups", time.Now().Format("2006-01-02_150405"))

	if err := EnsureDir(backupDir); err != nil {
		return "", err
	}

	for _, key := range configKeys {
		src := filepath.Join(homeDir, key)
		if _, err := os.Stat(src); err == nil {
			dst := filepath.Join(backupDir, filepath.Base(key))
			if info, err := os.Stat(src); err == nil && info.IsDir() {
				CopyDir(src, dst)
			} else {
				CopyFile(src, dst)
			}
		}
	}

	return backupDir, nil
}

// DetectExistingConfigs checks which configs already exist in the target locations
func DetectExistingConfigs(dotfilesDir, homeDir string) []string {
	existing := []string{}

	// Check .config entries
	configSource := filepath.Join(dotfilesDir, "home", ".config")
	if entries, err := os.ReadDir(configSource); err == nil {
		for _, entry := range entries {
			target := filepath.Join(homeDir, ".config", entry.Name())
			if _, err := os.Stat(target); err == nil {
				existing = append(existing, filepath.Join(".config", entry.Name()))
			}
		}
	}

	// Check home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		src := filepath.Join(dotfilesDir, f)
		if _, err := os.Stat(src); err == nil {
			target := filepath.Join(homeDir, f)
			if _, err := os.Stat(target); err == nil {
				existing = append(existing, f)
			}
		}
	}

	return existing
}

// Uninstall removes all deployed configs
func Uninstall(dotfilesDir, homeDir string) error {
	// Remove .config entries
	configSource := filepath.Join(dotfilesDir, "home", ".config")
	if entries, err := os.ReadDir(configSource); err == nil {
		for _, entry := range entries {
			target := filepath.Join(homeDir, ".config", entry.Name())
			os.RemoveAll(target)
		}
	}

	// Remove home dotfiles
	homeFiles := []string{".zshrc", ".zprofile", ".zalias", ".zfunc", ".zkey"}
	for _, f := range homeFiles {
		target := filepath.Join(homeDir, f)
		os.Remove(target)
	}

	// Remove manifest
	os.Remove(filepath.Join(dotfilesDir, "manifest.json"))

	return nil
}

// SaveManifest writes a simple deployment manifest
func SaveManifest(dotfilesDir string) error {
	manifest := struct {
		DeployedAt string `json:"deployed_at"`
		Version    string `json:"version"`
	}{
		DeployedAt: time.Now().Format(time.RFC3339),
		Version:    "1.0.0",
	}

	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filepath.Join(dotfilesDir, "manifest.json"), data, 0644)
}
