package tui

import (
	"flag"
	"os"
	"path/filepath"
	"strings"
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

// Task 6.3: renderWelcome contains skull and subtitle.
func TestRenderWelcomeContainsSkullAndSubtitle(t *testing.T) {
	m := Model{
		Screen:  ScreenWelcome,
		Width:   80,
		Height:  24,
		Palette: flavorPalettes["mocha"],
		SystemInfo: &system.SystemInfo{
			OSName: "macOS",
			Arch:   "arm64",
		},
	}
	out := renderWelcome(m)
	// Skull first line is a distinctive braille sequence.
	if !strings.Contains(out, "⠄⠄⠄⠄⠄⠄⠄⠄⠄⣀⣠⣤⣤⣤⣤⣀⡀⠄⠄⠄⠄⠄⠄⠄⠄") {
		t.Error("renderWelcome() missing skull braille first line")
	}
	if !strings.Contains(out, "Dotfiles Manager") {
		t.Error("renderWelcome() missing subtitle 'Dotfiles Manager'")
	}
}

// Task 6.4: renderThemeSelect contains step indicator with Theme active.
func TestRenderThemeSelectContainsStepIndicator(t *testing.T) {
	m := Model{
		Screen:        ScreenThemeSelect,
		Width:         80,
		Height:        24,
		Palette:       flavorPalettes["mocha"],
		SelectedTheme: "kanagawa",
		SelectedFlavor: "dragon",
		SystemInfo:    &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}
	out := renderThemeSelect(m)
	// Step indicator must contain "Theme" and "Flavor" labels.
	if !strings.Contains(out, "Theme") {
		t.Error("renderThemeSelect() missing 'Theme' step label")
	}
	if !strings.Contains(out, "Flavor") {
		t.Error("renderThemeSelect() missing 'Flavor' step label")
	}
}

// Task 6.5: RenderHelp formats three entries correctly.
func TestRenderHelpFormatsEntries(t *testing.T) {
	entries := []HelpEntry{
		{Key: "enter", Action: "select"},
		{Key: "j/k", Action: "navigate"},
		{Key: "q", Action: "quit"},
	}
	p := flavorPalettes["mocha"]
	out := RenderHelp(entries, p, 0)
	// Strip ANSI escapes for plain-text assertion.
	plain := stripANSI(out)
	if !strings.Contains(plain, "enter select") {
		t.Errorf("RenderHelp() missing 'enter select'; got: %q", plain)
	}
	if !strings.Contains(plain, "j/k navigate") {
		t.Errorf("RenderHelp() missing 'j/k navigate'; got: %q", plain)
	}
	if !strings.Contains(plain, "q quit") {
		t.Errorf("RenderHelp() missing 'q quit'; got: %q", plain)
	}
	if !strings.Contains(plain, "·") {
		t.Errorf("RenderHelp() missing '·' separator; got: %q", plain)
	}
}

// Task 6.6: CenterHorizontally with zero width returns input unchanged;
// with positive width returns padded output.
func TestCenterHorizontally(t *testing.T) {
	input := "abc"

	// Zero width: no-op.
	got := CenterHorizontally(input, 0)
	if got != input {
		t.Errorf("CenterHorizontally(0) = %q, want %q", got, input)
	}

	// Positive width: output width equals requested width.
	const w = 20
	got = CenterHorizontally(input, w)
	// lipgloss pads to exactly w visible cells; plain length may include ANSI.
	// Strip ANSI, then measure visible rune width (simple: count non-control runes).
	plain := stripANSI(got)
	if len([]rune(plain)) != w {
		t.Errorf("CenterHorizontally(%d) visible width = %d, want %d; out=%q", w, len([]rune(plain)), w, plain)
	}
}

// stripANSI removes ANSI escape sequences from s for plain-text assertions.
func stripANSI(s string) string {
	var b strings.Builder
	inEsc := false
	for _, r := range s {
		if r == '\x1b' {
			inEsc = true
			continue
		}
		if inEsc {
			if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
				inEsc = false
			}
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}
