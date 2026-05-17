package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

type Screen int

const (
	ScreenWelcome Screen = iota
	ScreenThemeSelect
	ScreenFlavorSelect
	ScreenThemePreview
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
