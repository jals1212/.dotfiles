package system

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestDetect(t *testing.T) {
	tests := []struct {
		name     string
		fs       FileSystem
		envSetup func()
		cleanup  func()
		checks   func(t *testing.T, info *SystemInfo)
		wantErr  bool
	}{
		{
			name: "basic detection returns info",
			fs:   OSFileSystem{},
			checks: func(t *testing.T, info *SystemInfo) {
				if info == nil {
					t.Fatal("expected non-nil SystemInfo")
				}
				if info.HomeDir == "" {
					t.Error("expected HomeDir to be set")
				}
				if info.Arch != runtime.GOARCH {
					t.Errorf("expected Arch=%s, got %s", runtime.GOARCH, info.Arch)
				}
				if info.InstalledTools == nil {
					t.Error("expected InstalledTools map to be initialized")
				}
			},
		},
		{
			name: "ARM architecture detection",
			fs:   OSFileSystem{},
			checks: func(t *testing.T, info *SystemInfo) {
				expectedARM := runtime.GOARCH == "arm64"
				if info.ARM != expectedARM {
					t.Errorf("expected ARM=%v, got %v", expectedARM, info.ARM)
				}
				if info.IsARM() != expectedARM {
					t.Errorf("expected IsARM()=%v, got %v", expectedARM, info.IsARM())
				}
			},
		},
		{
			name: "termux detection via env",
			fs:   OSFileSystem{},
			envSetup: func() {
				os.Setenv("TERMUX_VERSION", "0.118")
			},
			cleanup: func() {
				os.Unsetenv("TERMUX_VERSION")
			},
			checks: func(t *testing.T, info *SystemInfo) {
				if !info.Termux {
					t.Error("expected Termux to be true when TERMUX_VERSION is set")
				}
				if !info.IsTermux() {
					t.Error("expected IsTermux() to be true")
				}
				if info.OSName != "Termux (Android)" {
					t.Errorf("expected OSName='Termux (Android)', got %s", info.OSName)
				}
			},
		},
		{
			name: "detect with memfs debian",
			fs: func() FileSystem {
				mfs := NewMemFileSystem()
				mfs.MkdirAll("/etc/apt", 0755)
				return mfs
			}(),
			checks: func(t *testing.T, info *SystemInfo) {
				if runtime.GOOS != "linux" {
					t.Skip("skipping on non-linux platform")
				}
				if info.OS != OSDebian {
					t.Errorf("expected OS=OSDebian, got %v", info.OS)
				}
				if info.OSName != "Debian/Ubuntu" {
					t.Errorf("expected OSName='Debian/Ubuntu', got %s", info.OSName)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envSetup != nil {
				tt.envSetup()
				defer tt.cleanup()
			}
			info, err := Detect(tt.fs)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Detect() error = %v, wantErr %v", err, tt.wantErr)
			}
			tt.checks(t, info)
		})
	}
}

func TestDetectLinuxDistroFS(t *testing.T) {
	tests := []struct {
		name     string
		setupFS  func(fs *MemFileSystem)
		expected OS
	}{
		{
			name: "debian via apt",
			setupFS: func(fs *MemFileSystem) {
				fs.MkdirAll("/etc/apt", 0755)
			},
			expected: OSDebian,
		},
		{
			name: "debian via debian_version",
			setupFS: func(fs *MemFileSystem) {
				fs.WriteFile("/etc/debian_version", []byte("11.0\n"), 0644)
			},
			expected: OSDebian,
		},
		{
			name: "fedora via dnf",
			setupFS: func(fs *MemFileSystem) {
				fs.MkdirAll("/etc/dnf", 0755)
			},
			expected: OSFedora,
		},
		{
			name: "fedora via fedora-release",
			setupFS: func(fs *MemFileSystem) {
				fs.WriteFile("/etc/fedora-release", []byte("Fedora 40\n"), 0644)
			},
			expected: OSFedora,
		},
		{
			name: "arch via pacman",
			setupFS: func(fs *MemFileSystem) {
				fs.WriteFile("/etc/pacman.conf", []byte("[options]\n"), 0644)
			},
			expected: OSArch,
		},
		{
			name: "arch via arch-release",
			setupFS: func(fs *MemFileSystem) {
				fs.WriteFile("/etc/arch-release", []byte("\n"), 0644)
			},
			expected: OSArch,
		},
		{
			name:     "generic linux",
			setupFS:  func(fs *MemFileSystem) {},
			expected: OSLinux,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := NewMemFileSystem()
			tt.setupFS(fs)
			got := detectLinuxDistroFS(fs)
			if got != tt.expected {
				t.Errorf("detectLinuxDistroFS() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestCommandExists(t *testing.T) {
	tests := []struct {
		name     string
		cmd      string
		expected bool
	}{
		{
			name:     "echo command exists",
			cmd:      "echo",
			expected: true,
		},
		{
			name:     "nonexistent command",
			cmd:      "this_command_definitely_does_not_exist_12345",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CommandExists(tt.cmd)
			if got != tt.expected {
				t.Errorf("CommandExists(%q) = %v, want %v", tt.cmd, got, tt.expected)
			}
		})
	}
}

func TestFindDotfilesDirFS(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(t *testing.T) (cleanup func())
		expected string
	}{
		{
			name: "cwd with .config",
			setup: func(t *testing.T) (cleanup func()) {
				tmpDir := t.TempDir()
				configDir := filepath.Join(tmpDir, ".config")
				if err := os.MkdirAll(configDir, 0755); err != nil {
					t.Fatal(err)
				}
				origWd, _ := os.Getwd()
				os.Chdir(tmpDir)
				return func() { os.Chdir(origWd) }
			},
			expected: "", // will be the tmpDir
		},
		{
			name: "home dir .dotfiles",
			setup: func(t *testing.T) (cleanup func()) {
				tmpDir := t.TempDir()
				dotfilesDir := filepath.Join(tmpDir, ".dotfiles")
				if err := os.MkdirAll(dotfilesDir, 0755); err != nil {
					t.Fatal(err)
				}
				origHome := os.Getenv("HOME")
				os.Setenv("HOME", tmpDir)
				return func() { os.Setenv("HOME", origHome) }
			},
			expected: "", // will be tmpDir/.dotfiles
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanup := tt.setup(t)
			defer cleanup()
			got := findDotfilesDirFS(OSFileSystem{})
			if tt.expected != "" && got != tt.expected {
				t.Errorf("findDotfilesDirFS() = %q, want %q", got, tt.expected)
			}
			if got == "" {
				t.Error("findDotfilesDirFS() returned empty string")
			}
		})
	}
}

func TestReadFileFS(t *testing.T) {
	tests := []struct {
		name     string
		content  string
		wantErr  bool
		expected string
	}{
		{
			name:     "read existing file",
			content:  "hello world",
			wantErr:  false,
			expected: "hello world",
		},
		{
			name:    "read nonexistent file returns error",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var path string
			if tt.wantErr {
				path = filepath.Join(t.TempDir(), "nonexistent")
			} else {
				path = filepath.Join(t.TempDir(), "testfile")
				if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
					t.Fatal(err)
				}
			}

			got, err := readFileFS(OSFileSystem{}, path)
			if (err != nil) != tt.wantErr {
				t.Fatalf("readFileFS() error = %v, wantErr %v", err, tt.wantErr)
			}
			if !tt.wantErr && got != tt.expected {
				t.Errorf("readFileFS() = %q, want %q", got, tt.expected)
			}
		})
	}
}
