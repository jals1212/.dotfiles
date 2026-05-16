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
