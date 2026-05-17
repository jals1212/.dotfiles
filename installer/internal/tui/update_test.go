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
			name:       "theme-flavor panel=0 enter advances to tool select (any panel)",
			initial:    ScreenThemeFlavor,
			cursor:     0, // kanagawa
			panel:      0,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenToolSelect,
			wantCursor: 0,
		},
		{
			name:       "theme-flavor panel=1 enter advances to tool select",
			initial:    ScreenThemeFlavor,
			cursor:     0, // wave
			panel:      1,
			key:        tea.KeyMsg{Type: tea.KeyEnter},
			wantScreen: ScreenToolSelect,
			wantCursor: 0,
		},
		{
			name:       "tool select to backup confirm on install",
			initial:    ScreenToolSelect,
			cursor:     0, // any tool row triggers startInstall
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
		{name: "tool select", screen: ScreenToolSelect, want: len(defaultTools()) - 1},
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

// TestTabCyclesPanelFocus verifies Tab cycles Themes (0) → Flavors (1) → Themes (0).
// Panel domain is {0, 1}; there is no Continue panel.
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
	if got2.Panel != 0 {
		t.Errorf("after 2nd Tab Panel = %d, want 0 (wrap back to Themes)", got2.Panel)
	}
}

// TestTabCyclesTwoPanelsOnly verifies Tab only cycles between panel 0 and 1.
func TestTabCyclesTwoPanelsOnly(t *testing.T) {
	m := Model{
		Screen:         ScreenThemeFlavor,
		Palette:        flavorPalettes["mocha"],
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Panel:          0,
		SystemInfo:     &system.SystemInfo{OS: system.OSMac},
	}
	// Tab repeatedly; panel should never reach 2.
	for i := 0; i < 10; i++ {
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyTab})
		m = next.(Model)
		if m.Panel > 1 {
			t.Errorf("Tab produced Panel = %d at iteration %d; want <= 1", m.Panel, i)
		}
	}
}

// TestSpaceCommitsThemeOnPanel0 verifies Space on ScreenThemeFlavor panel 0 updates
// SelectedTheme, resets SelectedFlavor to default, updates Palette; Panel/Cursor unchanged.
func TestSpaceCommitsThemeOnPanel0(t *testing.T) {
	themes := defaultThemes()
	if len(themes) < 2 {
		t.Skip("need at least 2 themes")
	}
	// Start with catppuccin selected; hover kanagawa (index 0).
	m := Model{
		Screen:         ScreenThemeFlavor,
		Palette:        paletteFor("catppuccin", "mocha"),
		SelectedTheme:  "catppuccin",
		SelectedFlavor: "mocha",
		Panel:          0,
		Cursor:         0, // hovering kanagawa
		SystemInfo:     &system.SystemInfo{OS: system.OSMac},
	}
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{' '}})
	got := next.(Model)

	if got.SelectedTheme != "kanagawa" {
		t.Errorf("SelectedTheme = %q, want kanagawa", got.SelectedTheme)
	}
	wantFlavor := defaultFlavorForTheme("kanagawa")
	if got.SelectedFlavor != wantFlavor {
		t.Errorf("SelectedFlavor = %q, want %q (default for kanagawa)", got.SelectedFlavor, wantFlavor)
	}
	wantPalette := paletteFor("kanagawa", wantFlavor)
	if got.Palette != wantPalette {
		t.Errorf("Palette not updated after Space on panel 0")
	}
	if got.Panel != 0 {
		t.Errorf("Panel changed to %d, want 0", got.Panel)
	}
	if got.Cursor != 0 {
		t.Errorf("Cursor changed to %d, want 0", got.Cursor)
	}
}

// TestSpaceCommitsFlavorOnPanel1 verifies Space on ScreenThemeFlavor panel 1 updates
// SelectedFlavor and Palette; Panel/Cursor unchanged.
func TestSpaceCommitsFlavorOnPanel1(t *testing.T) {
	flavors := defaultFlavorsForTheme("kanagawa") // wave, dragon, lotus
	if len(flavors) < 2 {
		t.Skip("need at least 2 flavors")
	}
	// Start with wave selected; hover dragon (index 1).
	m := Model{
		Screen:         ScreenThemeFlavor,
		Palette:        paletteFor("kanagawa", "wave"),
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "wave",
		Panel:          1,
		Cursor:         1, // hovering dragon
		SystemInfo:     &system.SystemInfo{OS: system.OSMac},
	}
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{' '}})
	got := next.(Model)

	if got.SelectedFlavor != "dragon" {
		t.Errorf("SelectedFlavor = %q, want dragon", got.SelectedFlavor)
	}
	wantPalette := paletteFor("kanagawa", "dragon")
	if got.Palette != wantPalette {
		t.Errorf("Palette not updated after Space on panel 1")
	}
	if got.Panel != 1 {
		t.Errorf("Panel changed to %d, want 1", got.Panel)
	}
	if got.Cursor != 1 {
		t.Errorf("Cursor changed to %d, want 1", got.Cursor)
	}
}

// TestEnterAdvancesFromThemeFlavor verifies Enter on ScreenThemeFlavor always advances
// to ScreenToolSelect and saves PrevCursor/PrevPanel regardless of active panel.
func TestEnterAdvancesFromThemeFlavor(t *testing.T) {
	for _, panel := range []int{0, 1} {
		m := Model{
			Screen:         ScreenThemeFlavor,
			Palette:        paletteFor("kanagawa", "dragon"),
			SelectedTheme:  "kanagawa",
			SelectedFlavor: "dragon",
			Panel:          panel,
			Cursor:         2,
			SystemInfo:     &system.SystemInfo{OS: system.OSMac},
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
		got := next.(Model)

		if got.Screen != ScreenToolSelect {
			t.Errorf("panel=%d: Screen = %v, want ScreenToolSelect", panel, got.Screen)
		}
		if got.PrevCursor != 2 {
			t.Errorf("panel=%d: PrevCursor = %d, want 2", panel, got.PrevCursor)
		}
		if got.PrevPanel != panel {
			t.Errorf("panel=%d: PrevPanel = %d, want %d", panel, got.PrevPanel, panel)
		}
		if got.Cursor != 0 {
			t.Errorf("panel=%d: Cursor after advance = %d, want 0", panel, got.Cursor)
		}
	}
}

// TestSpaceTogglesToolRow verifies Space on ScreenToolSelect toggles Tools[Cursor].Selected.
func TestSpaceTogglesToolRow(t *testing.T) {
	m := Model{
		Screen:         ScreenToolSelect,
		Palette:        paletteFor("kanagawa", "dragon"),
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Tools:          defaultTools(),
		Cursor:         0,
		SystemInfo:     &system.SystemInfo{OS: system.OSMac},
	}
	initial := m.Tools[0].Selected
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{' '}})
	got := next.(Model)
	if got.Tools[0].Selected == initial {
		t.Errorf("Tools[0].Selected unchanged after Space; want %v, got %v", !initial, got.Tools[0].Selected)
	}
	if got.Cursor != 0 {
		t.Errorf("Cursor changed to %d after Space, want 0", got.Cursor)
	}
	// Toggle again — should revert.
	next2, _ := got.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{' '}})
	got2 := next2.(Model)
	if got2.Tools[0].Selected != initial {
		t.Errorf("Tools[0].Selected after double Space = %v, want %v (reverted)", got2.Tools[0].Selected, initial)
	}
}

// TestEnterAdvancesFromToolSelect verifies Enter on a tool row routes via startInstall.
// Without existing configs detected, the path goes directly to ScreenInstalling.
// With existing configs, it routes to ScreenBackupConfirm.
func TestEnterAdvancesFromToolSelect(t *testing.T) {
	tmp := t.TempDir()
	m := Model{
		Screen:         ScreenToolSelect,
		Palette:        paletteFor("kanagawa", "dragon"),
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Tools:          defaultTools(),
		Cursor:         0,
		SystemInfo: &system.SystemInfo{
			OS:          system.OSMac,
			HomeDir:     tmp,
			DotfilesDir: tmp,
		},
	}
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got := next.(Model)
	if got.Screen != ScreenInstalling && got.Screen != ScreenBackupConfirm {
		t.Errorf("Enter on ToolSelect: Screen=%v, want ScreenInstalling or ScreenBackupConfirm", got.Screen)
	}
}

// TestSpaceCommitsBackupChoice verifies Space on ScreenBackupConfirm sets BackupChoice = Cursor.
func TestSpaceCommitsBackupChoice(t *testing.T) {
	for _, row := range []int{0, 1, 2} {
		m := Model{
			Screen:       ScreenBackupConfirm,
			Palette:      paletteFor("kanagawa", "dragon"),
			SelectedTheme: "kanagawa",
			SelectedFlavor: "dragon",
			Cursor:       row,
			BackupChoice: 0, // default
			SystemInfo:   &system.SystemInfo{OS: system.OSMac},
		}
		next, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{' '}})
		got := next.(Model)
		if got.BackupChoice != row {
			t.Errorf("row=%d: BackupChoice = %d, want %d", row, got.BackupChoice, row)
		}
		if got.Cursor != row {
			t.Errorf("row=%d: Cursor changed to %d, want %d", row, got.Cursor, row)
		}
	}
}

// TestEnterAppliesBackupChoice verifies Enter on ScreenBackupConfirm routes by BackupChoice:
// choice=2 returns to ScreenToolSelect; choices 0/1 start installation.
func TestEnterAppliesBackupChoice(t *testing.T) {
	// BackupChoice = 2 → back to ToolSelect.
	m := Model{
		Screen:         ScreenBackupConfirm,
		Palette:        paletteFor("kanagawa", "dragon"),
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Cursor:         2,
		BackupChoice:   2,
		PrevCursor:     3,
		Tools:          defaultTools(),
		SystemInfo: &system.SystemInfo{
			OS:          system.OSMac,
			HomeDir:     t.TempDir(),
			DotfilesDir: t.TempDir(),
		},
	}
	next, _ := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got := next.(Model)
	if got.Screen != ScreenToolSelect {
		t.Errorf("BackupChoice=2: Screen = %v, want ScreenToolSelect", got.Screen)
	}
	if got.Cursor != 3 {
		t.Errorf("BackupChoice=2: Cursor = %d, want 3 (restored PrevCursor)", got.Cursor)
	}

	// BackupChoice = 0 → startInstalling (transitions to ScreenInstalling).
	m2 := Model{
		Screen:         ScreenBackupConfirm,
		Palette:        paletteFor("kanagawa", "dragon"),
		SelectedTheme:  "kanagawa",
		SelectedFlavor: "dragon",
		Cursor:         0,
		BackupChoice:   0,
		Tools:          defaultTools(),
		SystemInfo: &system.SystemInfo{
			OS:          system.OSMac,
			HomeDir:     t.TempDir(),
			DotfilesDir: t.TempDir(),
		},
	}
	next2, _ := m2.Update(tea.KeyMsg{Type: tea.KeyEnter})
	got2 := next2.(Model)
	if got2.Screen != ScreenInstalling {
		t.Errorf("BackupChoice=0: Screen = %v, want ScreenInstalling", got2.Screen)
	}
}
