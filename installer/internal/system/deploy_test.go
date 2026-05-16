package system

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestEnsureDir(t *testing.T) {
	tests := []struct {
		name    string
		wantErr bool
	}{
		{
			name:    "create new directory",
			wantErr: false,
		},
		{
			name:    "create nested directories",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			target := filepath.Join(tmpDir, "a", "b", "c")
			err := EnsureDir(target)
			if (err != nil) != tt.wantErr {
				t.Fatalf("EnsureDir() error = %v, wantErr %v", err, tt.wantErr)
			}
			info, err := os.Stat(target)
			if err != nil {
				t.Fatalf("expected dir to exist: %v", err)
			}
			if !info.IsDir() {
				t.Error("expected path to be a directory")
			}
		})
	}
}

func TestCopyFile(t *testing.T) {
	tests := []struct {
		name    string
		content string
		wantErr bool
	}{
		{
			name:    "copy simple file",
			content: "hello world",
			wantErr: false,
		},
		{
			name:    "copy empty file",
			content: "",
			wantErr: false,
		},
		{
			name:    "copy nonexistent file",
			content: "",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			src := filepath.Join(tmpDir, "src.txt")
			dst := filepath.Join(tmpDir, "dst.txt")

			if !tt.wantErr {
				if err := os.WriteFile(src, []byte(tt.content), 0644); err != nil {
					t.Fatal(err)
				}
			} else {
				src = filepath.Join(tmpDir, "nonexistent", "src.txt")
			}

			err := CopyFile(src, dst)
			if (err != nil) != tt.wantErr {
				t.Fatalf("CopyFile() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				data, err := os.ReadFile(dst)
				if err != nil {
					t.Fatal(err)
				}
				if string(data) != tt.content {
					t.Errorf("CopyFile() content = %q, want %q", string(data), tt.content)
				}
			}
		})
	}
}

func TestCopyDir(t *testing.T) {
	tests := []struct {
		name    string
		setup   func(t *testing.T, src string)
		wantErr bool
	}{
		{
			name: "copy directory with files",
			setup: func(t *testing.T, src string) {
				if err := os.WriteFile(filepath.Join(src, "a.txt"), []byte("a"), 0644); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(src, "b.txt"), []byte("b"), 0644); err != nil {
					t.Fatal(err)
				}
			},
			wantErr: false,
		},
		{
			name: "copy nested directories",
			setup: func(t *testing.T, src string) {
				sub := filepath.Join(src, "sub")
				if err := os.MkdirAll(sub, 0755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(sub, "c.txt"), []byte("c"), 0644); err != nil {
					t.Fatal(err)
				}
			},
			wantErr: false,
		},
		{
			name:    "copy nonexistent directory",
			setup:   func(t *testing.T, src string) {},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			src := filepath.Join(tmpDir, "src")
			dst := filepath.Join(tmpDir, "dst")

			if !tt.wantErr {
				if err := os.MkdirAll(src, 0755); err != nil {
					t.Fatal(err)
				}
				tt.setup(t, src)
			} else {
				src = filepath.Join(tmpDir, "nonexistent")
			}

			err := CopyDir(src, dst)
			if (err != nil) != tt.wantErr {
				t.Fatalf("CopyDir() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				// Verify files exist in dst
				entries, err := os.ReadDir(dst)
				if err != nil {
					t.Fatal(err)
				}
				if len(entries) == 0 {
					t.Error("expected copied directory to have entries")
				}
			}
		})
	}
}

func TestReplaceInFile(t *testing.T) {
	tests := []struct {
		name     string
		content  string
		old      string
		new      string
		expected string
		wantErr  bool
	}{
		{
			name:     "simple replacement",
			content:  "hello world",
			old:      "world",
			new:      "universe",
			expected: "hello universe",
			wantErr:  false,
		},
		{
			name:     "multiple replacements",
			content:  "foo bar foo",
			old:      "foo",
			new:      "baz",
			expected: "baz bar baz",
			wantErr:  false,
		},
		{
			name:    "nonexistent file",
			old:     "a",
			new:     "b",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			path := filepath.Join(tmpDir, "test.txt")

			if !tt.wantErr {
				if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
					t.Fatal(err)
				}
			} else {
				path = filepath.Join(tmpDir, "nonexistent", "test.txt")
			}

			err := ReplaceInFile(path, tt.old, tt.new)
			if (err != nil) != tt.wantErr {
				t.Fatalf("ReplaceInFile() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				data, err := os.ReadFile(path)
				if err != nil {
					t.Fatal(err)
				}
				if string(data) != tt.expected {
					t.Errorf("ReplaceInFile() = %q, want %q", string(data), tt.expected)
				}
			}
		})
	}
}

func TestReplaceBetweenMarkers(t *testing.T) {
	tests := []struct {
		name        string
		content     string
		startMarker string
		endMarker   string
		newContent  string
		expected    string
		wantErr     bool
	}{
		{
			name:        "replace between existing markers",
			content:     "before\n# BEGIN\nold\n# END\nafter",
			startMarker: "# BEGIN",
			endMarker:   "# END",
			newContent:  "new",
			expected:    "before\n# BEGIN\nnew\n# END\nafter",
			wantErr:     false,
		},
		{
			name:        "append markers when not found",
			content:     "existing content",
			startMarker: "# BEGIN",
			endMarker:   "# END",
			newContent:  "new",
			expected:    "existing content\n# BEGIN\nnew\n# END\n",
			wantErr:     false,
		},
		{
			name:        "append to empty file",
			content:     "",
			startMarker: "# BEGIN",
			endMarker:   "# END",
			newContent:  "new",
			expected:    "# BEGIN\nnew\n# END\n",
			wantErr:     false,
		},
		{
			name:        "append to file ending with newline",
			content:     "existing content\n",
			startMarker: "# BEGIN",
			endMarker:   "# END",
			newContent:  "new",
			expected:    "existing content\n# BEGIN\nnew\n# END\n",
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			path := filepath.Join(tmpDir, "test.txt")

			if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
				t.Fatal(err)
			}

			err := ReplaceBetweenMarkers(path, tt.startMarker, tt.endMarker, tt.newContent)
			if (err != nil) != tt.wantErr {
				t.Fatalf("ReplaceBetweenMarkers() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr {
				data, err := os.ReadFile(path)
				if err != nil {
					t.Fatal(err)
				}
				if string(data) != tt.expected {
					t.Errorf("ReplaceBetweenMarkers() = %q, want %q", string(data), tt.expected)
				}
			}
		})
	}
}

func TestCreateBackupWithMemFileSystem(t *testing.T) {
	fs := NewMemFileSystem()
	home := "/home/testuser"
	if err := fs.WriteFile(filepath.Join(home, ".zshrc"), []byte("zsh config"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".config", "nvim", "init.lua"), []byte("nvim config"), 0644); err != nil {
		t.Fatal(err)
	}

	backupDir, err := CreateBackup(fs, home, []string{".zshrc", ".config/nvim", ".missing"})
	if err != nil {
		t.Fatalf("CreateBackup() error = %v", err)
	}

	for _, path := range []string{
		filepath.Join(backupDir, ".zshrc"),
		filepath.Join(backupDir, ".config", "nvim", "init.lua"),
	} {
		if _, err := fs.Stat(path); err != nil {
			t.Fatalf("expected backup file %s: %v", path, err)
		}
	}
}

func TestLatestBackupWithMemFileSystem(t *testing.T) {
	tests := []struct {
		name    string
		setup   func(fs *MemFileSystem, home string)
		want    string
		wantErr bool
	}{
		{
			name: "selects lexicographically latest backup directory",
			setup: func(fs *MemFileSystem, home string) {
				for _, name := range []string{"2026-05-15_120000", "2026-05-16_090000", "2026-05-14_235959"} {
					if err := fs.MkdirAll(filepath.Join(home, ".dotfiles_backups", name), 0755); err != nil {
						t.Fatal(err)
					}
				}
				if err := fs.WriteFile(filepath.Join(home, ".dotfiles_backups", "README.txt"), []byte("not a dir"), 0644); err != nil {
					t.Fatal(err)
				}
			},
			want: filepath.Join("/home/testuser", ".dotfiles_backups", "2026-05-16_090000"),
		},
		{
			name:    "no backups returns error",
			setup:   func(fs *MemFileSystem, home string) {},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := NewMemFileSystem()
			home := "/home/testuser"
			tt.setup(fs, home)

			got, err := LatestBackup(fs, home)
			if (err != nil) != tt.wantErr {
				t.Fatalf("LatestBackup() error = %v, wantErr %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Fatalf("LatestBackup() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestRestoreBackupWithMemFileSystem(t *testing.T) {
	fs := NewMemFileSystem()
	home := "/home/testuser"
	backupDir := filepath.Join(home, ".dotfiles_backups", "2026-05-16_090000")

	if err := fs.WriteFile(filepath.Join(home, ".zshrc"), []byte("current zsh"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".config", "nvim", "init.lua"), []byte("current nvim"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(backupDir, ".zshrc"), []byte("backup zsh"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(backupDir, ".config", "nvim", "init.lua"), []byte("backup nvim"), 0644); err != nil {
		t.Fatal(err)
	}

	if err := RestoreBackup(fs, backupDir, home); err != nil {
		t.Fatalf("RestoreBackup() error = %v", err)
	}

	assertFileContent(t, fs, filepath.Join(home, ".zshrc"), "backup zsh")
	assertFileContent(t, fs, filepath.Join(home, ".config", "nvim", "init.lua"), "backup nvim")
}

func TestRestoreBackupMissingDirectory(t *testing.T) {
	fs := NewMemFileSystem()
	err := RestoreBackup(fs, "/home/testuser/.dotfiles_backups/missing", "/home/testuser")
	if err == nil {
		t.Fatal("RestoreBackup() expected error for missing backup")
	}
}

func assertFileContent(t *testing.T, fs FileSystem, path, want string) {
	t.Helper()
	data, err := fs.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile(%q) error = %v", path, err)
	}
	if string(data) != want {
		t.Fatalf("ReadFile(%q) = %q, want %q", path, data, want)
	}
}

func TestDetectExistingConfigsWithMemFileSystem(t *testing.T) {
	fs := NewMemFileSystem()
	dotfilesDir := "/repo"
	home := "/home/testuser"

	if err := fs.MkdirAll(filepath.Join(dotfilesDir, "home", ".config", "nvim"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(dotfilesDir, "home", ".zshrc"), []byte("managed zsh"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.MkdirAll(filepath.Join(home, ".config", "nvim"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".zshrc"), []byte("user zsh"), 0644); err != nil {
		t.Fatal(err)
	}

	got := DetectExistingConfigs(fs, dotfilesDir, home)
	for _, want := range []string{".config/nvim", ".zshrc"} {
		if !slices.Contains(got, want) {
			t.Fatalf("DetectExistingConfigs() = %#v, want %q", got, want)
		}
	}
}

func TestUninstallWithMemFileSystem(t *testing.T) {
	fs := NewMemFileSystem()
	dotfilesDir := "/repo"
	home := "/home/testuser"

	if err := fs.MkdirAll(filepath.Join(dotfilesDir, "home", ".config", "nvim"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".config", "nvim", "init.lua"), []byte("nvim"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".zshrc"), []byte("zsh"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(home, ".dotfiles_backups", "keep", ".zshrc"), []byte("backup"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := fs.WriteFile(filepath.Join(dotfilesDir, "manifest.json"), []byte("{}"), 0644); err != nil {
		t.Fatal(err)
	}

	if err := Uninstall(fs, dotfilesDir, home); err != nil {
		t.Fatalf("Uninstall() error = %v", err)
	}
	for _, removed := range []string{
		filepath.Join(home, ".config", "nvim", "init.lua"),
		filepath.Join(home, ".zshrc"),
		filepath.Join(dotfilesDir, "manifest.json"),
	} {
		if _, err := fs.Stat(removed); err == nil {
			t.Fatalf("expected %s to be removed", removed)
		}
	}
	if _, err := fs.Stat(filepath.Join(home, ".dotfiles_backups", "keep", ".zshrc")); err != nil {
		t.Fatalf("backup should remain: %v", err)
	}
}

func TestSaveManifestWithFlavor(t *testing.T) {
	tests := []struct {
		name       string
		theme      string
		flavor     string
		wantTheme  string
		wantFlavor string
	}{
		{
			name:       "explicit theme and flavor",
			theme:      "catppuccin",
			flavor:     "macchiato",
			wantTheme:  "catppuccin",
			wantFlavor: "macchiato",
		},
		{
			name:       "defaults to kanagawa dragon",
			wantTheme:  "kanagawa",
			wantFlavor: "dragon",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := NewMemFileSystem()
			dotfilesDir := "/repo"
			if err := SaveManifest(fs, dotfilesDir, tt.theme, tt.flavor); err != nil {
				t.Fatalf("SaveManifest() error = %v", err)
			}

			data, err := fs.ReadFile(filepath.Join(dotfilesDir, "manifest.json"))
			if err != nil {
				t.Fatalf("manifest not written: %v", err)
			}
			var manifest Manifest
			if err := json.Unmarshal(data, &manifest); err != nil {
				t.Fatalf("manifest JSON invalid: %v", err)
			}
			if manifest.Theme != tt.wantTheme {
				t.Fatalf("manifest theme = %q, want %q", manifest.Theme, tt.wantTheme)
			}
			if manifest.Flavor != tt.wantFlavor {
				t.Fatalf("manifest flavor = %q, want %q", manifest.Flavor, tt.wantFlavor)
			}
			if manifest.DeployedAt == "" {
				t.Fatal("manifest deployed_at should be populated")
			}
			if manifest.Version == "" {
				t.Fatal("manifest version should be populated")
			}
		})
	}
}
