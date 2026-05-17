package system

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestApplyBlock_FirstApply(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.sh")
	body := `export BAT_THEME="Catppuccin-mocha"`

	if err := ApplyBlock(path, "bat", body); err != nil {
		t.Fatalf("ApplyBlock error: %v", err)
	}
	data, _ := os.ReadFile(path)
	got := string(data)

	if !strings.Contains(got, "# dots:bat begin") {
		t.Error("missing begin marker")
	}
	if !strings.Contains(got, "# dots:bat end") {
		t.Error("missing end marker")
	}
	if !strings.Contains(got, body) {
		t.Errorf("missing body; got:\n%s", got)
	}
}

func TestApplyBlock_SecondApplyReplacesBody(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.sh")

	if err := ApplyBlock(path, "bat", `export BAT_THEME="Catppuccin-mocha"`); err != nil {
		t.Fatalf("first ApplyBlock error: %v", err)
	}
	if err := ApplyBlock(path, "bat", `export BAT_THEME="Catppuccin-latte"`); err != nil {
		t.Fatalf("second ApplyBlock error: %v", err)
	}

	data, _ := os.ReadFile(path)
	got := string(data)

	if strings.Count(got, "# dots:bat begin") != 1 {
		t.Fatalf("expected exactly one begin marker; got:\n%s", got)
	}
	if strings.Count(got, "# dots:bat end") != 1 {
		t.Fatalf("expected exactly one end marker; got:\n%s", got)
	}
	if strings.Contains(got, "mocha") {
		t.Fatalf("old body still present:\n%s", got)
	}
	if !strings.Contains(got, "latte") {
		t.Fatalf("new body missing:\n%s", got)
	}
}

func TestApplyBlock_Idempotent(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.sh")
	body := `export EZA_COLORS="*.go=34"`

	if err := ApplyBlock(path, "eza", body); err != nil {
		t.Fatalf("first ApplyBlock error: %v", err)
	}
	before, _ := os.ReadFile(path)

	if err := ApplyBlock(path, "eza", body); err != nil {
		t.Fatalf("second ApplyBlock error: %v", err)
	}
	after, _ := os.ReadFile(path)

	if string(before) != string(after) {
		t.Fatalf("idempotent: file changed on second apply\nbefore:\n%s\nafter:\n%s", before, after)
	}
}

func TestRemoveBlock_RemovesBlock(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".zshrc")
	existing := "before content\n"
	if err := os.WriteFile(path, []byte(existing), 0644); err != nil {
		t.Fatal(err)
	}

	body := `export BAT_THEME="Catppuccin-mocha"`
	if err := ApplyBlock(path, "bat", body); err != nil {
		t.Fatalf("ApplyBlock error: %v", err)
	}
	if err := RemoveBlock(path, "bat"); err != nil {
		t.Fatalf("RemoveBlock error: %v", err)
	}

	data, _ := os.ReadFile(path)
	got := string(data)

	if strings.Contains(got, "# dots:bat") {
		t.Fatalf("sentinel markers still present:\n%s", got)
	}
	if strings.Contains(got, body) {
		t.Fatalf("body still present:\n%s", got)
	}
	if !strings.Contains(got, "before content") {
		t.Fatalf("content before block was damaged:\n%s", got)
	}
}

func TestRemoveBlock_ContentOutsidePreserved(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".zshrc")
	content := "line-before\n# dots:eza begin\nexport EZA_COLORS=''\n# dots:eza end\nline-after\n"
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	if err := RemoveBlock(path, "eza"); err != nil {
		t.Fatalf("RemoveBlock error: %v", err)
	}

	data, _ := os.ReadFile(path)
	got := string(data)

	if strings.Contains(got, "# dots:eza") {
		t.Fatalf("sentinel still present:\n%s", got)
	}
	if !strings.Contains(got, "line-before") {
		t.Fatalf("line-before lost:\n%s", got)
	}
	if !strings.Contains(got, "line-after") {
		t.Fatalf("line-after lost:\n%s", got)
	}
}

func TestRemoveBlock_MissingSentinelIsNoOp(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, ".zshrc")
	content := "just some content\n"
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	if err := RemoveBlock(path, "bat"); err != nil {
		t.Fatalf("RemoveBlock on missing sentinel error: %v", err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != content {
		t.Fatalf("file modified unexpectedly:\n%s", data)
	}
}

func TestRemoveBlock_MissingFileIsNoOp(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nonexistent")
	if err := RemoveBlock(path, "bat"); err != nil {
		t.Fatalf("RemoveBlock on nonexistent file error: %v", err)
	}
}
