package system

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// ReplaceInFile reads a file, replaces all occurrences of old with new, and writes it back.
func ReplaceInFile(path, old, new string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	original := string(data)
	content := strings.ReplaceAll(original, old, new)
	if content == original {
		return nil
	}
	return os.WriteFile(path, []byte(content), 0644)
}

// CopyFile copies a file from src to dst, preserving permissions
func CopyFile(src, dst string) error {
	_, err := CopyFileIfChanged(src, dst)
	return err
}

// CopyFileIfChanged copies a file from src to dst only when content differs.
func CopyFileIfChanged(src, dst string) (bool, error) {
	info, err := os.Stat(src)
	if err != nil {
		return false, err
	}

	// Create parent directory
	if err := EnsureDir(filepath.Dir(dst)); err != nil {
		return false, err
	}

	// If dst exists and is a directory, remove it
	if dstInfo, err := os.Stat(dst); err == nil && dstInfo.IsDir() {
		if err := os.RemoveAll(dst); err != nil {
			return false, err
		}
	}

	data, err := os.ReadFile(src)
	if err != nil {
		return false, err
	}

	if existing, err := os.ReadFile(dst); err == nil && bytes.Equal(existing, data) {
		return false, nil
	}

	return true, os.WriteFile(dst, data, info.Mode())
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
			dst := filepath.Join(backupDir, key)
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

// ListBackups returns backup directories under $HOME/.dotfiles_backups sorted by name.
func ListBackups(fs FileSystem, homeDir string) ([]string, error) {
	backupRoot := filepath.Join(homeDir, ".dotfiles_backups")
	entries, err := fs.ReadDir(backupRoot)
	if err != nil {
		return nil, fmt.Errorf("list backups: %w", err)
	}

	backups := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			backups = append(backups, filepath.Join(backupRoot, entry.Name()))
		}
	}
	sort.Strings(backups)
	return backups, nil
}

// LatestBackup returns the most recent backup directory by lexicographic timestamp order.
func LatestBackup(fs FileSystem, homeDir string) (string, error) {
	backups, err := ListBackups(fs, homeDir)
	if err != nil {
		return "", err
	}
	if len(backups) == 0 {
		return "", fmt.Errorf("no backups found in %s", filepath.Join(homeDir, ".dotfiles_backups"))
	}
	return backups[len(backups)-1], nil
}

// RestoreBackup copies every entry from backupDir back into homeDir.
func RestoreBackup(fs FileSystem, backupDir, homeDir string) error {
	info, err := fs.Stat(backupDir)
	if err != nil {
		return fmt.Errorf("restore backup: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("restore backup: %s is not a directory", backupDir)
	}

	entries, err := fs.ReadDir(backupDir)
	if err != nil {
		return fmt.Errorf("restore backup: %w", err)
	}
	for _, entry := range entries {
		src := filepath.Join(backupDir, entry.Name())
		dst := filepath.Join(homeDir, entry.Name())
		if entry.IsDir() {
			if err := copyDirFS(fs, src, dst); err != nil {
				return fmt.Errorf("restore %s: %w", entry.Name(), err)
			}
			continue
		}
		if err := copyFileFS(fs, src, dst); err != nil {
			return fmt.Errorf("restore %s: %w", entry.Name(), err)
		}
	}
	return nil
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
	homeFiles := []string{".zshenv"}
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
	homeFiles := []string{".zshenv"}
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
	SourceHash string `json:"source_hash"`
}

// DeploymentSourceHash computes a stable hash of deploy source inputs.
func DeploymentSourceHash(fs FileSystem, dotfilesDir string) (string, error) {
	hasher := sha256.New()
	for _, rel := range []string{"home", filepath.Join("assets", "themes")} {
		if err := hashSourcePath(fs, hasher, dotfilesDir, rel); err != nil {
			return "", err
		}
	}
	return fmt.Sprintf("%x", hasher.Sum(nil)), nil
}

func hashSourcePath(fs FileSystem, w io.Writer, dotfilesDir, rel string) error {
	fullPath := filepath.Join(dotfilesDir, rel)
	info, err := fs.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			_, _ = fmt.Fprintf(w, "missing:%s\n", filepath.ToSlash(rel))
			return nil
		}
		return fmt.Errorf("hash source %s: %w", rel, err)
	}

	normalizedRel := filepath.ToSlash(rel)
	if info.IsDir() {
		_, _ = fmt.Fprintf(w, "dir:%s\n", normalizedRel)
		entries, err := fs.ReadDir(fullPath)
		if err != nil {
			return fmt.Errorf("hash source %s: %w", rel, err)
		}
		sort.Slice(entries, func(i, j int) bool {
			return entries[i].Name() < entries[j].Name()
		})
		for _, entry := range entries {
			if err := hashSourcePath(fs, w, dotfilesDir, filepath.Join(rel, entry.Name())); err != nil {
				return err
			}
		}
		return nil
	}

	data, err := fs.ReadFile(fullPath)
	if err != nil {
		return fmt.Errorf("hash source %s: %w", rel, err)
	}
	_, _ = fmt.Fprintf(w, "file:%s:%d\n", normalizedRel, len(data))
	if _, err := w.Write(data); err != nil {
		return fmt.Errorf("hash source %s: %w", rel, err)
	}
	_, _ = fmt.Fprint(w, "\n")
	return nil
}

// LoadManifest reads manifest.json from the dotfiles directory.
func LoadManifest(fs FileSystem, dotfilesDir string) (Manifest, error) {
	data, err := fs.ReadFile(filepath.Join(dotfilesDir, "manifest.json"))
	if err != nil {
		return Manifest{}, err
	}
	var manifest Manifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return Manifest{}, err
	}
	return manifest, nil
}

// NeedsReload reports whether deploy source inputs differ from the stored manifest hash.
func NeedsReload(fs FileSystem, dotfilesDir string) (bool, string, string, error) {
	currentHash, err := DeploymentSourceHash(fs, dotfilesDir)
	if err != nil {
		return false, "", "", err
	}

	manifest, err := LoadManifest(fs, dotfilesDir)
	if err != nil {
		if os.IsNotExist(err) {
			return true, currentHash, "", nil
		}
		return false, currentHash, "", err
	}
	if manifest.SourceHash == "" {
		return true, currentHash, "", nil
	}
	return manifest.SourceHash != currentHash, currentHash, manifest.SourceHash, nil
}

// SaveManifest writes a simple deployment manifest
func SaveManifest(fs FileSystem, dotfilesDir, theme, flavor string) error {
	if theme == "" {
		theme = "kanagawa"
	}
	if flavor == "" {
		flavor = "dragon"
	}
	sourceHash, err := DeploymentSourceHash(fs, dotfilesDir)
	if err != nil {
		return err
	}
	manifest := Manifest{
		DeployedAt: time.Now().Format(time.RFC3339),
		Version:    "1.0.0",
		Theme:      theme,
		Flavor:     flavor,
		SourceHash: sourceHash,
	}

	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}

	return fs.WriteFile(filepath.Join(dotfilesDir, "manifest.json"), data, 0644)
}
