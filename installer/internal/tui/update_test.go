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
		panel      int
		key        tea.KeyMsg
		wantScreen Screen
		wantCursor int
		setup      func(m *Model)
	}{
		{
			name:       "welcome to theme-flavor",
			initial:    ScreenWelcome,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenThemeFlavor,
			wantCursor: 0, // kanagawa is index 0
		},
		{
			name:       "theme-flavor panel=0 enter commits theme, moves to panel 1",
			initial:    ScreenThemeFlavor,
			cursor:     0, // kanagawa
			panel:      0,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenThemeFlavor,
			// cursor lands on dragon (index 1 in kanagawa flavors: wave=0, dragon=1, lotus=2)
			wantCursor: 1,
		},
		{
			name:       "theme-flavor panel=1 enter commits flavor, moves to Continue (panel 2)",
			initial:    ScreenThemeFlavor,
			cursor:     0, // wave
			panel:      1,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenThemeFlavor,
			wantCursor: 0,
		},
		{
			name:       "theme-flavor panel=2 enter advances to tool select",
			initial:    ScreenThemeFlavor,
			cursor:     0,
			panel:      2,
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
			name:       "esc from theme-flavor returns to welcome",
			initial:    ScreenThemeFlavor,
			key:        tea.KeyMsg{Type: tea.KeyEscape},
			wantScreen: ScreenWelcome,
			wantCursor: 0,
		},
		{
			name:       "esc from tool select restores theme-flavor",
			initial:    ScreenToolSelect,
			key:        tea.KeyMsg{Type: tea.KeyEscape},
			wantScreen: ScreenThemeFlavor,
			wantCursor: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m := Model{
				Screen:        tt.initial,
				PrevScreen:    ScreenWelcome,
				Cursor:        tt.cursor,
				Panel:         tt.panel,
				Tools:         defaultTools(),
				Palette:       flavorPalettes["mocha"],
				SelectedTheme: "kanagawa",
				SelectedFlavor: "dragon",
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
		{name: "theme-flavor", screen: ScreenThemeFlavor, want: 0},
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

// TestEscFromToolSelectRestoresPanelAndCursor verifies Esc from ToolSelect
// restores the saved panel and cursor position from ScreenThemeFlavor.
func TestEscFromToolSelectRestoresPanelAndCursor(t *testing.T) {
	m := Model{
		Screen:         ScreenToolSelect,
		PrevScreen:     ScreenThemeFlavor,
		Cursor:         3,
		Panel:          0,
		PrevCursor:     2,
		PrevPanel:      1,
		Tools:          defaultTools(),
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "wave",
		SystemInfo: &system.SystemInfo{
			OS:          system.OSMac,
			HomeDir:     t.TempDir(),
			DotfilesDir: t.TempDir(),
		},
	}
	newModel, _ := m.Update(tea.KeyMsg{Type: tea.KeyEscape})
	got, ok := newModel.(Model)
	if !ok {
		t.Fatal("Update did not return a Model")
	}
	if got.Screen != ScreenThemeFlavor {
		t.Errorf("Screen = %v, want ScreenThemeFlavor", got.Screen)
	}
	if got.Panel != 1 {
		t.Errorf("Panel = %d, want 1", got.Panel)
	}
	if got.Cursor != 2 {
		t.Errorf("Cursor = %d, want 2", got.Cursor)
	}
}

// TestTabCyclesPanelFocus verifies Tab cycles Themes→Flavors→Continue→Themes.
func TestTabCyclesPanelFocus(t *testing.T) {
	base := Model{
		Screen:         ScreenThemeFlavor,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		Cursor:         0,
		SystemInfo:     &system.SystemInfo{OS: system.OSMac},
	}

	m1, _ := base.Update(tea.KeyMsg{Type: tea.KeyTab})
	got1 := m1.(Model)
	if got1.Panel != 1 {
		t.Errorf("after 1st Tab Panel = %d, want 1", got1.Panel)
	}

	m2, _ := got1.Update(tea.KeyMsg{Type: tea.KeyTab})
	got2 := m2.(Model)
	if got2.Panel != 2 {
		t.Errorf("after 2nd Tab Panel = %d, want 2", got2.Panel)
	}

	m3, _ := got2.Update(tea.KeyMsg{Type: tea.KeyTab})
	got3 := m3.(Model)
	if got3.Panel != 0 {
		t.Errorf("after 3rd Tab Panel = %d, want 0 (wrap)", got3.Panel)
	}
}
