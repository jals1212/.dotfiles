package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

type Screen int

const (
	ScreenWelcome Screen = iota
	ScreenThemeFlavor
	ScreenToolSelect
	ScreenBackupConfirm
	ScreenInstalling
	ScreenSummary
	ScreenError
)

type Tool struct {
	Name        string
	Description string
	Selected    bool
	Category    string // "terminal", "shell", "editor", "tool"
}

type InstallStep struct {
	ID          string
	Name        string
	Status      StepStatus
	Detail      string // Additional info (e.g., which packages)
	Interactive bool   // Step requires user interaction (e.g., sudo)
}

type StepStatus int

const (
	StatusPending StepStatus = iota
	StatusRunning
	StatusDone
	StatusFailed
	StatusSkipped
)

type Model struct {
	Screen           Screen
	PrevScreen       Screen
	Width            int
	Height           int
	Cursor           int
	// Panel tracks focus on ScreenThemeFlavor: 0=Themes, 1=Flavors. Domain is {0, 1}.
	Panel            int
	// PrevCursor and PrevPanel store cursor/panel before a forward screen transition
	// so Esc can restore them.
	PrevCursor       int
	PrevPanel        int
	// BackupChoice is set by Space on ScreenBackupConfirm: 0=with backup, 1=without backup, 2=cancel.
	BackupChoice     int
	SystemInfo       *system.SystemInfo
	Tools            []Tool
	Steps            []InstallStep
	CurrentStep      int
	Quitting         bool
	ErrorMsg         string
	SpinnerFrame     int
	ShowDetails      bool
	LogLines         []string
	ExistingConfigs  []string
	BackupDir        string
	IsNonInteractive bool
	QuietLogs        bool
	SelectedTheme    string
	SelectedFlavor   string
	SelectedAccent   string
	Palette          Palette
}

func NewModel() (Model, error) {
	info, err := system.Detect(system.OSFileSystem{})
	if err != nil {
		return Model{}, err
	}
	return Model{
		Screen:         ScreenWelcome,
		PrevScreen:     ScreenWelcome,
		SystemInfo:     info,
		Tools:          defaultTools(),
		CurrentStep:    0,
		SpinnerFrame:   0,
		LogLines:       []string{},
		SelectedTheme:  defaultTheme,
		SelectedFlavor: defaultFlavor,
		SelectedAccent: defaultAccent,
		Palette:        paletteFor(defaultTheme, defaultFlavor),
	}, nil
}

func (m Model) Init() tea.Cmd {
	return tea.EnterAltScreen
}
