package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

type Screen int

const (
	ScreenWelcome Screen = iota
	ScreenFlavorSelect
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
	SelectedFlavor   string
	SelectedAccent   string
}

func NewModel() (Model, error) {
	info, err := system.Detect()
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
		SelectedFlavor: "mocha",
		SelectedAccent: "mauve",
	}, nil
}

func defaultFlavors() []string {
	return []string{"latte", "frappe", "macchiato", "mocha"}
}

func defaultTools() []Tool {
	return []Tool{
		{Name: "ghostty", Description: "Ghostty terminal (Catppuccin + Iosevka)", Selected: true, Category: "terminal"},
		{Name: "tmux", Description: "Tmux multiplexer (TPM + Catppuccin)", Selected: true, Category: "tool"},
		{Name: "nvim", Description: "Neovim (LazyVim + Catppuccin)", Selected: true, Category: "editor"},
		{Name: "starship", Description: "Starship prompt (Catppuccin)", Selected: true, Category: "shell"},
		{Name: "atuin", Description: "Atuin shell history", Selected: true, Category: "shell"},
		{Name: "zoxide", Description: "Zoxide smart cd", Selected: true, Category: "shell"},
		{Name: "zsh", Description: "ZSH config (zinit + aliases)", Selected: true, Category: "shell"},
	}
}

func (m Model) Init() tea.Cmd {
	return tea.EnterAltScreen
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	return update(m, msg)
}

func (m Model) View() string {
	return renderView(m)
}
