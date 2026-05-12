package system

import (
	"os"
	"path/filepath"
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
