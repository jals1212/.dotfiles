package tui

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func TestThemeAssetPathPrefersNestedThemeDirectory(t *testing.T) {
	dir := t.TempDir()
	nested := filepath.Join(dir, "assets", "themes", "ghostty", "catppuccin")
	if err := os.MkdirAll(nested, 0755); err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(nested, "mocha.conf")
	if err := os.WriteFile(want, []byte("theme"), 0644); err != nil {
		t.Fatal(err)
	}

	got := themeAssetPath(dir, "ghostty", "catppuccin", "mocha.conf", "mocha.conf")
	if got != want {
		t.Fatalf("themeAssetPath() = %q, want %q", got, want)
	}
}

func TestCatppuccinAssetsAreNestedLikeKanagawa(t *testing.T) {
	tools := map[string][]string{
		"atuin":    {"mocha.toml"},
		"bat":      {"Catppuccin-mocha.tmTheme"},
		"bottom":   {"mocha.toml"},
		"eza":      {"mocha.txt"},
		"fzf":      {"mocha.sh"},
		"ghostty":  {"mocha.conf"},
		"lazygit":  {"mocha.yml"},
		"starship": {"mocha.toml"},
	}
	for tool, files := range tools {
		for _, file := range files {
			path := filepath.Join("..", "..", "assets", "themes", tool, "catppuccin", file)
			if _, err := os.Stat(path); err != nil {
				t.Fatalf("expected nested Catppuccin asset %s: %v", path, err)
			}
		}
	}
}

func TestAtuinCatppuccinUsesFlavorOnlyAssets(t *testing.T) {
	dir := filepath.Join("..", "..", "assets", "themes", "atuin", "catppuccin")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}

	got := []string{}
	for _, entry := range entries {
		if !entry.IsDir() {
			got = append(got, entry.Name())
		}
	}
	sort.Strings(got)

	want := []string{
		"frappe.toml",
		"latte.toml",
		"macchiato.toml",
		"mocha.toml",
	}
	if len(got) != len(want) {
		t.Fatalf("Atuin Catppuccin assets = %#v, want exactly %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("Atuin Catppuccin assets = %#v, want %#v", got, want)
		}
	}
}

func TestAtuinCatppuccinNameUsesFlavorOnly(t *testing.T) {
	got := atuinThemeName("catppuccin", "mocha", "blue")
	want := "mocha"
	if got != want {
		t.Fatalf("atuinThemeName() = %q, want %q", got, want)
	}
}

func TestStarshipMarkersSurviveThemeReplacement(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "starship.toml")
	content := `palette = "DOTS_STARSHIP_PALETTE"
# DOTS_STARSHIP_BLOCK_START
[palettes.DOTS_STARSHIP_PALETTE]
base = "#000000"
# DOTS_STARSHIP_BLOCK_END
`
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	if err := replaceThemeInFile(path, "kanagawa", "dragon", "mauve"); err != nil {
		t.Fatal(err)
	}
	gotBytes, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	got := string(gotBytes)
	if !strings.Contains(got, "# DOTS_STARSHIP_BLOCK_START") || !strings.Contains(got, "# DOTS_STARSHIP_BLOCK_END") {
		t.Fatalf("starship markers were corrupted:\n%s", got)
	}
	if strings.Contains(got, "DOTS_STARSHIP_PALETTE") {
		t.Fatalf("starship palette placeholder was not replaced:\n%s", got)
	}
}

func TestThemeReplacementSkipsPluginDirectories(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "plugins", "catppuccin-tmux"), 0755); err != nil {
		t.Fatal(err)
	}
	pluginFile := filepath.Join(dir, "plugins", "catppuccin-tmux", "theme.conf")
	if err := os.WriteFile(pluginFile, []byte("DOTS_THEME_FLAVOR"), 0000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = os.Chmod(pluginFile, 0644)
	})

	if err := replaceThemeInDir(dir, "kanagawa", "dragon", "mauve"); err != nil {
		t.Fatalf("replaceThemeInDir should skip plugin dirs, got error: %v", err)
	}
}

func TestShouldSkipConfigEntry(t *testing.T) {
	if !shouldSkipConfigEntry(".DS_Store") {
		t.Fatal("expected .DS_Store to be skipped")
	}
	if shouldSkipConfigEntry("nvim") {
		t.Fatal("did not expect nvim to be skipped")
	}
}
