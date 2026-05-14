package tui

import (
	"testing"
)

func TestNewModel(t *testing.T) {
	m, err := NewModel()
	if err != nil {
		t.Fatalf("NewModel() error = %v", err)
	}
	if m.Screen != ScreenWelcome {
		t.Errorf("Screen = %v, want %v", m.Screen, ScreenWelcome)
	}
	if m.PrevScreen != ScreenWelcome {
		t.Errorf("PrevScreen = %v, want %v", m.PrevScreen, ScreenWelcome)
	}
	if m.SelectedTheme != "kanagawa" {
		t.Errorf("SelectedTheme = %q, want %q", m.SelectedTheme, "kanagawa")
	}
	if m.SelectedFlavor != "dragon" {
		t.Errorf("SelectedFlavor = %q, want %q", m.SelectedFlavor, "dragon")
	}
	if m.SelectedAccent != "mauve" {
		t.Errorf("SelectedAccent = %q, want %q", m.SelectedAccent, "mauve")
	}
	if m.Palette != paletteFor("kanagawa", "dragon") {
		t.Errorf("Palette = %+v, want %+v", m.Palette, paletteFor("kanagawa", "dragon"))
	}
	if len(m.Tools) != len(defaultTools()) {
		t.Errorf("len(Tools) = %d, want %d", len(m.Tools), len(defaultTools()))
	}
	if m.SystemInfo == nil {
		t.Error("SystemInfo is nil")
	}
}

func TestDefaultTools(t *testing.T) {
	tests := []struct {
		name  string
		count int
		want  []string
	}{
		{
			name:  "default tools count and names",
			count: 7,
			want: []string{
				"ghostty", "tmux", "nvim", "starship",
				"atuin", "zoxide", "zsh",
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tools := defaultTools()
			if len(tools) != tt.count {
				t.Errorf("len(defaultTools()) = %d, want %d", len(tools), tt.count)
			}
			for i, name := range tt.want {
				if i >= len(tools) {
					t.Fatalf("defaultTools() has %d items, expected at least %d", len(tools), i+1)
				}
				if tools[i].Name != name {
					t.Errorf("defaultTools()[%d].Name = %q, want %q", i, tools[i].Name, name)
				}
			}
		})
	}
}

func TestDefaultFlavors(t *testing.T) {
	tests := []struct {
		name  string
		count int
		want  []string
	}{
		{
			name:  "default flavors count and values",
			count: 4,
			want:  []string{"latte", "frappe", "macchiato", "mocha"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			flavors := defaultFlavors()
			if len(flavors) != tt.count {
				t.Errorf("len(defaultFlavors()) = %d, want %d", len(flavors), tt.count)
			}
			for i, v := range tt.want {
				if i >= len(flavors) {
					t.Fatalf("defaultFlavors() has %d items, expected at least %d", len(flavors), i+1)
				}
				if flavors[i] != v {
					t.Errorf("defaultFlavors()[%d] = %q, want %q", i, flavors[i], v)
				}
			}
		})
	}
}

func TestDefaultThemes(t *testing.T) {
	themes := defaultThemes()
	if len(themes) != 2 {
		t.Fatalf("len(defaultThemes()) = %d, want 2", len(themes))
	}
	if themes[0].Name != "kanagawa" {
		t.Errorf("default theme = %q, want kanagawa", themes[0].Name)
	}
	if got := defaultFlavorsForTheme("kanagawa"); len(got) != 3 || got[0] != "wave" || got[1] != "dragon" || got[2] != "lotus" {
		t.Errorf("defaultFlavorsForTheme(kanagawa) = %#v", got)
	}
}
