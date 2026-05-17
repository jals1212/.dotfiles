package system

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDetectShell(t *testing.T) {
	tests := []struct {
		env  string
		want Shell
	}{
		{"/bin/zsh", ShellZsh},
		{"/usr/bin/zsh", ShellZsh},
		{"/bin/bash", ShellBash},
		{"/usr/local/bin/bash", ShellBash},
		{"/usr/bin/fish", ShellFish},
		{"", ShellUnknown},
		{"/bin/sh", ShellUnknown},
	}

	for _, tt := range tests {
		t.Run(tt.env, func(t *testing.T) {
			t.Setenv("SHELL", tt.env)
			got := DetectShell()
			if got != tt.want {
				t.Fatalf("DetectShell() = %v, want %v (SHELL=%q)", got, tt.want, tt.env)
			}
		})
	}
}

func TestRCFilePaths(t *testing.T) {
	home := "/home/testuser"
	tests := []struct {
		shell Shell
		check func(got string) bool
		desc  string
	}{
		{ShellZsh, func(got string) bool { return got == filepath.Join(home, ".zshrc") }, ".zshrc for zsh"},
		{ShellFish, func(got string) bool { return strings.HasSuffix(got, "config.fish") }, "config.fish for fish"},
		{ShellUnknown, func(got string) bool { return strings.HasSuffix(got, ".profile") }, ".profile for unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.desc, func(t *testing.T) {
			got := RCFile(tt.shell, home)
			if !tt.check(got) {
				t.Fatalf("RCFile(%v, %q) = %q, unexpected", tt.shell, home, got)
			}
		})
	}
}

func TestAppendLineIfMissing_Idempotent(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, ".zshrc")
	line := `export FOO="bar"`

	// First call: line absent — should append.
	if err := AppendLineIfMissing(rc, line); err != nil {
		t.Fatalf("first AppendLineIfMissing error: %v", err)
	}
	data, _ := os.ReadFile(rc)
	if strings.Count(string(data), line) != 1 {
		t.Fatalf("after first append: count=%d, want 1\n%s", strings.Count(string(data), line), data)
	}

	// Second call: line present — file must not change.
	if err := AppendLineIfMissing(rc, line); err != nil {
		t.Fatalf("second AppendLineIfMissing error: %v", err)
	}
	data2, _ := os.ReadFile(rc)
	if strings.Count(string(data2), line) != 1 {
		t.Fatalf("after second append: count=%d, want 1\n%s", strings.Count(string(data2), line), data2)
	}
}

func TestAppendLineIfMissing_CreatesFile(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, "new.rc")
	line := "export PATH=$HOME/bin:$PATH"

	if err := AppendLineIfMissing(rc, line); err != nil {
		t.Fatalf("AppendLineIfMissing on new file: %v", err)
	}
	data, err := os.ReadFile(rc)
	if err != nil {
		t.Fatalf("ReadFile: %v", err)
	}
	if !strings.Contains(string(data), line) {
		t.Fatalf("line missing from new file:\n%s", data)
	}
}

func TestAppendLineIfMissing_NoLeadingNewlineWhenFileEndsWithNewline(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, ".zshrc")
	if err := os.WriteFile(rc, []byte("existing line\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := AppendLineIfMissing(rc, "new line"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(rc)
	if string(data) != "existing line\nnew line\n" {
		t.Fatalf("unexpected content:\n%q", string(data))
	}
}

func TestRemoveLineIfPresent_Idempotent(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, ".zshrc")
	content := "line one\nexport FOO=bar\nline three\n"
	if err := os.WriteFile(rc, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	line := "export FOO=bar"
	// First remove.
	if err := RemoveLineIfPresent(rc, line); err != nil {
		t.Fatalf("first RemoveLineIfPresent error: %v", err)
	}
	data, _ := os.ReadFile(rc)
	if strings.Contains(string(data), line) {
		t.Fatalf("line still present after removal:\n%s", data)
	}

	// Second remove: no-op, no error.
	if err := RemoveLineIfPresent(rc, line); err != nil {
		t.Fatalf("second RemoveLineIfPresent error: %v", err)
	}
}

func TestRemoveLineIfPresent_MissingFileIsNoOp(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, "nonexistent.rc")
	if err := RemoveLineIfPresent(rc, "some line"); err != nil {
		t.Fatalf("RemoveLineIfPresent on missing file error: %v", err)
	}
}

func TestRemoveLineIfPresent_PreservesOtherContent(t *testing.T) {
	dir := t.TempDir()
	rc := filepath.Join(dir, ".zshrc")
	content := "alpha\nbeta\ngamma\n"
	if err := os.WriteFile(rc, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	if err := RemoveLineIfPresent(rc, "beta"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(rc)
	if strings.Contains(string(data), "beta") {
		t.Fatal("beta still present")
	}
	if !strings.Contains(string(data), "alpha") || !strings.Contains(string(data), "gamma") {
		t.Fatalf("surrounding content damaged:\n%s", data)
	}
}
