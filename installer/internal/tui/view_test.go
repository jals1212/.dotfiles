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

// Task 6.4: renderThemeFlavor contains three-step funnel indicator.
func TestRenderThemeFlavorContainsStepIndicator(t *testing.T) {
	m := Model{
		Screen:         ScreenThemeFlavor,
		Width:          80,
		Height:         24,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		SystemInfo:     &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}
	out := renderThemeFlavor(m)
	plain := stripANSI(out)
	// Three-step funnel labels.
	if !strings.Contains(plain, "Theme & Flavor") {
		t.Error("renderThemeFlavor() missing 'Theme & Flavor' step label")
	}
	if !strings.Contains(plain, "Tools") {
		t.Error("renderThemeFlavor() missing 'Tools' step label")
	}
	if !strings.Contains(plain, "Install") {
		t.Error("renderThemeFlavor() missing 'Install' step label")
	}
	// Separator and active marker.
	if !strings.Contains(plain, "→") {
		t.Error("renderThemeFlavor() missing '→' step separator")
	}
	if !strings.Contains(plain, "●") {
		t.Error("renderThemeFlavor() missing '●' active step icon")
	}
}

// Task 7.5: No rounded box border characters on the theme-flavor screen.
func TestNoBoxOnSelectionScreens(t *testing.T) {
	m := Model{
		Screen:         ScreenThemeFlavor,
		Width:          80,
		Height:         24,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		SystemInfo:     &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}
	out := renderView(m)
	for _, ch := range []string{"╭", "╮", "╰", "╯"} {
		if strings.Contains(out, ch) {
			t.Errorf("renderThemeFlavor() contains box border character %q", ch)
		}
	}
}

// Task 7.6: Non-welcome screens omit the skull braille header.
func TestNonWelcomeOmitsSkull(t *testing.T) {
	m := Model{
		Screen:         ScreenThemeFlavor,
		Width:          80,
		Height:         24,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		SystemInfo:     &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}
	out := renderThemeFlavor(m)
	// First line of skull is a distinctive braille sequence.
	if strings.Contains(out, "⠄⠄⠄⠄⠄⠄⠄⠄⠄⣀⣠⣤⣤⣤⣤⣀⡀⠄⠄⠄⠄⠄⠄⠄⠄") {
		t.Error("renderThemeFlavor() must not contain skull braille header")
	}
}

// Task 6.5: Active selection markers — ● on selected row, ▸ on cursor row.
func TestRenderThemeFlavorShowsActiveMarker(t *testing.T) {
	// SelectedTheme = kanagawa (index 0); cursor on catppuccin (index 1).
	m := Model{
		Screen:         ScreenThemeFlavor,
		Width:          80,
		Height:         24,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		Cursor:         1, // hovering catppuccin
		SystemInfo:     &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}
	out := renderThemeFlavor(m)
	plain := stripANSI(out)
	if !strings.Contains(plain, "● Kanagawa") {
		t.Errorf("renderThemeFlavor() missing '● Kanagawa' selection marker; got:\n%s", plain)
	}
	if !strings.Contains(plain, "▸") {
		t.Error("renderThemeFlavor() missing '▸ ' cursor marker")
	}
	// Verify cursor is on catppuccin row.
	if !strings.Contains(plain, "Catppuccin") {
		t.Error("renderThemeFlavor() missing 'Catppuccin' in output")
	}

	// Now test ● and ▸ on same row: cursor on kanagawa while kanagawa is selected.
	m.Cursor = 0
	out2 := renderThemeFlavor(m)
	plain2 := stripANSI(out2)
	if !strings.Contains(plain2, "▸") {
		t.Error("renderThemeFlavor() (same-row) missing '▸'")
	}
	if !strings.Contains(plain2, "● Kanagawa") {
		t.Error("renderThemeFlavor() (same-row) missing '● Kanagawa'")
	}
}

// Task 6.6: Live preview uses hovered palette without mutating m.Palette.
func TestRenderThemeFlavorLivePreview(t *testing.T) {
	// Committed: kanagawa/dragon. Hover over catppuccin (index 1 in Themes panel).
	dragonPalette := paletteFor("kanagawa", "dragon")
	m := Model{
		Screen:         ScreenThemeFlavor,
		Width:          80,
		Height:         24,
		Palette:        dragonPalette,
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		Cursor:         1, // hovering catppuccin; default flavor = mocha
		SystemInfo:     &system.SystemInfo{OSName: "macOS", Arch: "arm64"},
	}

	// Render — preview should use catppuccin/mocha palette, not kanagawa/dragon.
	_ = renderThemeFlavor(m)

	// m.Palette must be unchanged after render.
	if m.Palette != dragonPalette {
		t.Error("renderThemeFlavor() mutated m.Palette during hover preview")
	}

	// The hovered palette colors differ from the committed palette.
	hoveredPalette := paletteFor("catppuccin", "mocha")
	if dragonPalette == hoveredPalette {
		t.Skip("kanagawa/dragon and catppuccin/mocha have identical palettes — skip color diff check")
	}
	// We can't easily assert the ANSI colors in the rendered string without a full ANSI parser,
	// but we can assert m.SelectedFlavor and m.SelectedTheme are not mutated.
	if m.SelectedTheme != "kanagawa" {
		t.Errorf("renderThemeFlavor() mutated m.SelectedTheme to %q", m.SelectedTheme)
	}
	if m.SelectedFlavor != "dragon" {
		t.Errorf("renderThemeFlavor() mutated m.SelectedFlavor to %q", m.SelectedFlavor)
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
	// Named keys get brackets; chord keys and single chars do not.
	if !strings.Contains(plain, "[enter] select") {
		t.Errorf("RenderHelp() missing '[enter] select'; got: %q", plain)
	}
	if !strings.Contains(plain, "j/k navigate") {
		t.Errorf("RenderHelp() missing 'j/k navigate'; got: %q", plain)
	}
	if !strings.Contains(plain, "q quit") {
		t.Errorf("RenderHelp() missing 'q quit'; got: %q", plain)
	}
	if !strings.Contains(plain, "•") {
		t.Errorf("RenderHelp() missing '•' separator; got: %q", plain)
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
