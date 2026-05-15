package tui

import (
	"flag"
	"os"
	"path/filepath"
	"testing"

	"github.com/jals/dotfiles/internal/system"
)

var updateGolden = flag.Bool("update", false, "update golden files")

func TestWelcomeView(t *testing.T) {
	m := Model{
		Screen: ScreenWelcome,
		Width:  80,
		Height: 24,
		Palette: flavorPalettes["mocha"],
		SystemInfo: &system.SystemInfo{
			OSName: "macOS",
			Arch:   "arm64",
		},
	}

	output := renderView(m)

	golden := filepath.Join("testdata", "TestWelcomeView.golden")
	if *updateGolden {
		if err := os.MkdirAll("testdata", 0755); err != nil {
			t.Fatalf("failed to create testdata dir: %v", err)
		}
		if err := os.WriteFile(golden, []byte(output), 0644); err != nil {
			t.Fatalf("failed to update golden file: %v", err)
		}
		return
	}

	expected, err := os.ReadFile(golden)
	if err != nil {
		t.Fatalf("failed to read golden file: %v", err)
	}

	if string(expected) != output {
		t.Errorf("renderView() mismatch\nexpected:\n%s\ngot:\n%s", string(expected), output)
	}
}
