package system

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// memFileInfo implements os.FileInfo for MemFileSystem.
type memFileInfo struct {
	name    string
	size    int64
	mode    os.FileMode
	modTime time.Time
	isDir   bool
}

func (m *memFileInfo) Name() string       { return m.name }
func (m *memFileInfo) Size() int64        { return m.size }
func (m *memFileInfo) Mode() os.FileMode  { return m.mode }
func (m *memFileInfo) ModTime() time.Time { return m.modTime }
func (m *memFileInfo) IsDir() bool        { return m.isDir }
func (m *memFileInfo) Sys() interface{}   { return nil }

type memDirEntry struct {
	name string
	info os.FileInfo
}

func (m *memDirEntry) Name() string               { return m.name }
func (m *memDirEntry) IsDir() bool                { return m.info.IsDir() }
func (m *memDirEntry) Type() os.FileMode          { return m.info.Mode().Type() }
func (m *memDirEntry) Info() (os.FileInfo, error) { return m.info, nil }

// MemFileSystem is an in-memory filesystem for testing.
type MemFileSystem struct {
	files map[string][]byte
	dirs  map[string]bool
	home  string
}

func NewMemFileSystem() *MemFileSystem {
	return &MemFileSystem{
		files: make(map[string][]byte),
		dirs:  make(map[string]bool),
		home:  "/home/testuser",
	}
}

func (m *MemFileSystem) SetHome(home string) { m.home = home }

func (m *MemFileSystem) Stat(name string) (os.FileInfo, error) {
	name = filepath.Clean(name)
	if m.dirs[name] {
		return &memFileInfo{name: filepath.Base(name), mode: os.ModeDir | 0755, isDir: true}, nil
	}
	if data, ok := m.files[name]; ok {
		return &memFileInfo{name: filepath.Base(name), size: int64(len(data)), mode: 0644}, nil
	}
	return nil, os.ErrNotExist
}

func (m *MemFileSystem) ReadFile(name string) ([]byte, error) {
	name = filepath.Clean(name)
	if data, ok := m.files[name]; ok {
		return data, nil
	}
	return nil, os.ErrNotExist
}

func (m *MemFileSystem) WriteFile(name string, data []byte, perm os.FileMode) error {
	name = filepath.Clean(name)
	m.files[name] = data
	m.ensureDirs(name)
	return nil
}

func (m *MemFileSystem) MkdirAll(path string, perm os.FileMode) error {
	path = filepath.Clean(path)
	m.dirs[path] = true
	m.ensureDirs(path)
	return nil
}

func (m *MemFileSystem) ensureDirs(name string) {
	dir := filepath.Dir(name)
	for dir != "/" && dir != "." {
		m.dirs[dir] = true
		dir = filepath.Dir(dir)
	}
}

func (m *MemFileSystem) Remove(name string) error {
	name = filepath.Clean(name)
	delete(m.files, name)
	delete(m.dirs, name)
	return nil
}

func (m *MemFileSystem) RemoveAll(path string) error {
	path = filepath.Clean(path)
	for name := range m.files {
		if strings.HasPrefix(name, path+"/") || name == path {
			delete(m.files, name)
		}
	}
	for dir := range m.dirs {
		if strings.HasPrefix(dir, path+"/") || dir == path {
			delete(m.dirs, dir)
		}
	}
	return nil
}

func (m *MemFileSystem) ReadDir(name string) ([]os.DirEntry, error) {
	name = filepath.Clean(name)
	if !m.dirs[name] {
		hasEntries := false
		for f := range m.files {
			if filepath.Dir(f) == name {
				hasEntries = true
				break
			}
		}
		if !hasEntries {
			return nil, os.ErrNotExist
		}
	}
	entries := map[string]os.DirEntry{}
	for f, data := range m.files {
		if filepath.Dir(f) == name {
			base := filepath.Base(f)
			entries[base] = &memDirEntry{
				name: base,
				info: &memFileInfo{name: base, size: int64(len(data)), mode: 0644},
			}
		}
	}
	for d := range m.dirs {
		if filepath.Dir(d) == name && d != name {
			base := filepath.Base(d)
			if _, ok := entries[base]; !ok {
				entries[base] = &memDirEntry{
					name: base,
					info: &memFileInfo{name: base, mode: os.ModeDir | 0755, isDir: true},
				}
			}
		}
	}
	var result []os.DirEntry
	for _, e := range entries {
		result = append(result, e)
	}
	return result, nil
}

func (m *MemFileSystem) UserHomeDir() (string, error) {
	return m.home, nil
}

// Helper to populate a home directory with common config files.
func (m *MemFileSystem) PopulateHome() {
	m.WriteFile(filepath.Join(m.home, ".zshrc"), []byte("zsh config"), 0644)
	m.WriteFile(filepath.Join(m.home, ".zprofile"), []byte("zprofile"), 0644)
	m.WriteFile(filepath.Join(m.home, ".zalias"), []byte("alias"), 0644)
	m.WriteFile(filepath.Join(m.home, ".zfunc"), []byte("func"), 0644)
	m.WriteFile(filepath.Join(m.home, ".zkey"), []byte("key"), 0644)
	m.WriteFile(filepath.Join(m.home, ".config", "nvim", "init.lua"), []byte("nvim"), 0644)
}

func TestMemFileSystem(t *testing.T) {
	tests := []struct {
		name string
		test func(t *testing.T, fs *MemFileSystem)
	}{
		{
			name: "write and read file",
			test: func(t *testing.T, fs *MemFileSystem) {
				path := "/tmp/test.txt"
				if err := fs.WriteFile(path, []byte("hello"), 0644); err != nil {
					t.Fatalf("WriteFile error: %v", err)
				}
				data, err := fs.ReadFile(path)
				if err != nil {
					t.Fatalf("ReadFile error: %v", err)
				}
				if string(data) != "hello" {
					t.Errorf("content = %q, want %q", string(data), "hello")
				}
			},
		},
		{
			name: "stat file",
			test: func(t *testing.T, fs *MemFileSystem) {
				path := "/tmp/stat.txt"
				fs.WriteFile(path, []byte("abc"), 0644)
				info, err := fs.Stat(path)
				if err != nil {
					t.Fatalf("Stat error: %v", err)
				}
				if info.Name() != "stat.txt" {
					t.Errorf("Name = %q, want %q", info.Name(), "stat.txt")
				}
				if info.Size() != 3 {
					t.Errorf("Size = %d, want %d", info.Size(), 3)
				}
			},
		},
		{
			name: "stat missing returns error",
			test: func(t *testing.T, fs *MemFileSystem) {
				_, err := fs.Stat("/tmp/missing")
				if err == nil {
					t.Error("expected error for missing file")
				}
			},
		},
		{
			name: "mkdir and read dir",
			test: func(t *testing.T, fs *MemFileSystem) {
				fs.MkdirAll("/tmp/a/b", 0755)
				fs.WriteFile("/tmp/a/f1.txt", []byte("1"), 0644)
				fs.WriteFile("/tmp/a/b/f2.txt", []byte("2"), 0644)
				entries, err := fs.ReadDir("/tmp/a")
				if err != nil {
					t.Fatalf("ReadDir error: %v", err)
				}
				found := map[string]bool{}
				for _, e := range entries {
					found[e.Name()] = true
				}
				if !found["f1.txt"] {
					t.Error("expected f1.txt in dir")
				}
				if !found["b"] {
					t.Error("expected b in dir")
				}
			},
		},
		{
			name: "remove file",
			test: func(t *testing.T, fs *MemFileSystem) {
				path := "/tmp/del.txt"
				fs.WriteFile(path, []byte("x"), 0644)
				if err := fs.Remove(path); err != nil {
					t.Fatalf("Remove error: %v", err)
				}
				_, err := fs.Stat(path)
				if err == nil {
					t.Error("expected file to be removed")
				}
			},
		},
		{
			name: "remove all recursive",
			test: func(t *testing.T, fs *MemFileSystem) {
				fs.WriteFile("/tmp/rm/a.txt", []byte("a"), 0644)
				fs.WriteFile("/tmp/rm/b/c.txt", []byte("c"), 0644)
				if err := fs.RemoveAll("/tmp/rm"); err != nil {
					t.Fatalf("RemoveAll error: %v", err)
				}
				_, err := fs.Stat("/tmp/rm")
				if err == nil {
					t.Error("expected dir to be removed")
				}
				_, err = fs.Stat("/tmp/rm/a.txt")
				if err == nil {
					t.Error("expected a.txt to be removed")
				}
			},
		},
		{
			name: "user home dir",
			test: func(t *testing.T, fs *MemFileSystem) {
				home, err := fs.UserHomeDir()
				if err != nil {
					t.Fatalf("UserHomeDir error: %v", err)
				}
				if home != "/home/testuser" {
					t.Errorf("home = %q, want %q", home, "/home/testuser")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := NewMemFileSystem()
			tt.test(t, fs)
		})
	}
}
