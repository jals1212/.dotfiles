package tui

import (
	"os"
	"path/filepath"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

func TestScreenTransitions(t *testing.T) {
	tests := []struct {
		name       string
		initial    Screen
		cursor     int
		key        tea.KeyMsg
		wantScreen Screen
		wantCursor int
		setup      func(m *Model)
	}{
		{
			name:       "welcome to theme select",
			initial:    ScreenWelcome,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenThemeSelect,
			wantCursor: 0,
		},
		{
			name:       "theme select to flavor select on continue",
			initial:    ScreenThemeSelect,
			cursor:     len(defaultThemes()), // Continue button
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenFlavorSelect,
			wantCursor: 0,
		},
		{
			name:       "flavor select to theme preview on continue",
			initial:    ScreenFlavorSelect,
			cursor:     len(defaultFlavorsForTheme("kanagawa")), // Continue button
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenThemePreview,
			wantCursor: 0,
		},
		{
			name:       "theme preview to tool select on continue",
			initial:    ScreenThemePreview,
			cursor:     0,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenToolSelect,
			wantCursor: 0,
		},
		{
			name:       "tool select to backup confirm on install",
			initial:    ScreenToolSelect,
			cursor:     len(defaultTools()), // Install button
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenBackupConfirm,
			wantCursor: 0,
			setup: func(m *Model) {
				// Create fake existing config to trigger backup confirm
				homeDir := t.TempDir()
				dotfilesDir := t.TempDir()
				configDir := filepath.Join(dotfilesDir, "home", ".config")
				os.MkdirAll(configDir, 0755)
				os.WriteFile(filepath.Join(configDir, "nvim"), []byte{}, 0644)
				targetConfigDir := filepath.Join(homeDir, ".config")
				os.MkdirAll(targetConfigDir, 0755)
				os.WriteFile(filepath.Join(targetConfigDir, "nvim"), []byte{}, 0644)

				m.SystemInfo = &system.SystemInfo{
					OS:          system.OSMac,
					HomeDir:     homeDir,
					DotfilesDir: dotfilesDir,
				}
			},
		},
		{
			name:       "esc returns to prev screen",
			initial:    ScreenFlavorSelect,
			key:        tea.KeyMsg{Type: tea.KeyEscape},
			wantScreen: ScreenWelcome,
			wantCursor: 0,
			setup: func(m *Model) {
				m.PrevScreen = ScreenWelcome
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m := Model{
				Screen:     tt.initial,
				PrevScreen: ScreenWelcome,
				Cursor:     tt.cursor,
				Tools:      defaultTools(),
				Palette:    flavorPalettes["mocha"],
				SystemInfo: &system.SystemInfo{
					OS:          system.OSMac,
					HomeDir:     t.TempDir(),
					DotfilesDir: t.TempDir(),
				},
			}
			if tt.setup != nil {
				tt.setup(&m)
			}

			newModel, _ := m.Update(tt.key)
			if newModel, ok := newModel.(Model); ok {
				if newModel.Screen != tt.wantScreen {
					t.Errorf("Screen = %v, want %v", newModel.Screen, tt.wantScreen)
				}
				if newModel.Cursor != tt.wantCursor {
					t.Errorf("Cursor = %d, want %d", newModel.Cursor, tt.wantCursor)
				}
			} else {
				t.Fatalf("Update did not return a Model")
			}
		})
	}
}

func TestMaxCursor(t *testing.T) {
	tests := []struct {
		name   string
		screen Screen
		want   int
	}{
		{name: "welcome", screen: ScreenWelcome, want: 0},
		{name: "theme select", screen: ScreenThemeSelect, want: len(defaultThemes())},
		{name: "flavor select", screen: ScreenFlavorSelect, want: len(defaultFlavorsForTheme("kanagawa"))},
		{name: "theme preview", screen: ScreenThemePreview, want: 0},
		{name: "tool select", screen: ScreenToolSelect, want: len(defaultTools())},
		{name: "backup confirm", screen: ScreenBackupConfirm, want: 2},
		{name: "installing", screen: ScreenInstalling, want: 0},
		{name: "summary", screen: ScreenSummary, want: 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m := Model{Screen: tt.screen, Tools: defaultTools(), SelectedTheme: "kanagawa", SelectedFlavor: "dragon"}
			got := maxCursor(m)
			if got != tt.want {
				t.Errorf("maxCursor() = %d, want %d", got, tt.want)
			}
		})
	}
}
