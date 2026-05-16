package main

import (
	"path/filepath"
	"testing"

	"github.com/jals/dotfiles/internal/system"
)

func TestResolveRestoreBackupPath(t *testing.T) {
	tmp := t.TempDir()
	backupRoot := filepath.Join(tmp, ".dotfiles_backups")
	fs := system.OSFileSystem{}
	for _, name := range []string{"2026-05-15_120000", "2026-05-16_090000"} {
		if err := fs.MkdirAll(filepath.Join(backupRoot, name), 0755); err != nil {
			t.Fatal(err)
		}
	}

	tests := []struct {
		name    string
		args    []string
		want    string
		wantErr bool
	}{
		{
			name: "latest flag selects latest backup",
			args: []string{"--latest"},
			want: filepath.Join(backupRoot, "2026-05-16_090000"),
		},
		{
			name: "specific path is returned",
			args: []string{filepath.Join(backupRoot, "2026-05-15_120000")},
			want: filepath.Join(backupRoot, "2026-05-15_120000"),
		},
		{
			name:    "missing selection errors",
			args:    []string{},
			wantErr: true,
		},
		{
			name:    "latest and path conflict",
			args:    []string{"--latest", filepath.Join(backupRoot, "2026-05-15_120000")},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := resolveRestoreBackupPath(fs, tmp, tt.args)
			if (err != nil) != tt.wantErr {
				t.Fatalf("resolveRestoreBackupPath() error = %v, wantErr %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Fatalf("resolveRestoreBackupPath() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestResolveReloadOptions(t *testing.T) {
	tests := []struct {
		name      string
		args      []string
		wantForce bool
		wantErr   bool
	}{
		{
			name: "default conditional reload",
		},
		{
			name:      "force reload",
			args:      []string{"--force"},
			wantForce: true,
		},
		{
			name:    "unexpected positional argument",
			args:    []string{"extra"},
			wantErr: true,
		},
		{
			name:    "unknown flag",
			args:    []string{"--wat"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := resolveReloadOptions(tt.args)
			if (err != nil) != tt.wantErr {
				t.Fatalf("resolveReloadOptions() error = %v, wantErr %v", err, tt.wantErr)
			}
			if got != tt.wantForce {
				t.Fatalf("resolveReloadOptions() = %v, want %v", got, tt.wantForce)
			}
		})
	}
}

func TestIsHelpArg(t *testing.T) {
	tests := []struct {
		arg  string
		want bool
	}{
		{arg: "help", want: true},
		{arg: "-h", want: true},
		{arg: "--help", want: true},
		{arg: "extra", want: false},
		{arg: "", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.arg, func(t *testing.T) {
			if got := isHelpArg(tt.arg); got != tt.want {
				t.Fatalf("isHelpArg(%q) = %v, want %v", tt.arg, got, tt.want)
			}
		})
	}
}

func TestValidateNoArgCommand(t *testing.T) {
	tests := []struct {
		name     string
		command  string
		args     []string
		wantHelp bool
		wantErr  bool
	}{
		{
			name:    "no args allowed",
			command: "update",
		},
		{
			name:     "help arg is detected",
			command:  "update",
			args:     []string{"--help"},
			wantHelp: true,
		},
		{
			name:    "unexpected arg errors",
			command: "update",
			args:    []string{"extra"},
			wantErr: true,
		},
		{
			name:    "multiple args errors even with help",
			command: "uninstall",
			args:    []string{"--help", "extra"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotHelp, err := validateNoArgCommand(tt.command, tt.args)
			if (err != nil) != tt.wantErr {
				t.Fatalf("validateNoArgCommand() error = %v, wantErr %v", err, tt.wantErr)
			}
			if gotHelp != tt.wantHelp {
				t.Fatalf("validateNoArgCommand() help = %v, want %v", gotHelp, tt.wantHelp)
			}
		})
	}
}
