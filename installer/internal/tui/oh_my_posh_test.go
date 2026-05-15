package tui

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestOhMyPoshThemeAssetsCoverSupportedFlavors(t *testing.T) {
	want := map[string][]string{
		"catppuccin": {"latte", "frappe", "macchiato", "mocha"},
		"kanagawa":   {"wave", "dragon", "lotus"},
	}

	for theme, flavors := range want {
		for _, flavor := range flavors {
			path := filepath.Join("..", "..", "..", "assets", "themes", "oh-my-posh", theme, flavor+".json")
			data, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("expected Oh My Posh asset %s: %v", path, err)
			}

			var cfg map[string]any
			if err := json.Unmarshal(data, &cfg); err != nil {
				t.Fatalf("Oh My Posh asset %s must be valid JSON: %v", path, err)
			}
			assertOhMyPoshConfigSegments(t, path, data)
		}
	}
}

func TestHomeOhMyPoshConfigIsValidDefaultTheme(t *testing.T) {
	path := filepath.Join("..", "..", "..", "home", ".config", "oh-my-posh", "config.json")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("expected default Oh My Posh config %s: %v", path, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(data, &cfg); err != nil {
		t.Fatalf("home Oh My Posh config must be valid JSON: %v", err)
	}
	assertOhMyPoshConfigSegments(t, "home/.config/oh-my-posh/config.json", data)
}

func assertOhMyPoshConfigSegments(t *testing.T, path string, data []byte) {
	t.Helper()

	got := string(data)
	for _, segment := range []string{
		`"type": "path"`,
		`"type": "git"`,
		`"type": "node"`,
		`"type": "go"`,
		`"type": "python"`,
		`"type": "executiontime"`,
		`"type": "time"`,
		`"type": "text"`,
	} {
		if !strings.Contains(got, segment) {
			t.Fatalf("%s missing Oh My Posh segment %s", path, segment)
		}
	}
	if strings.Contains(strings.ToLower(got), "starship") {
		t.Fatalf("%s should not reference Starship", path)
	}
	if strings.Contains(got, "DOTS_") {
		t.Fatalf("%s should be a deployable theme asset without unresolved DOTS placeholders", path)
	}
}
