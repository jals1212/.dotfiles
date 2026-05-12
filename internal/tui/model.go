package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/jals/dotfiles/internal/system"
)

type Screen int

const (
	ScreenWelcome Screen = iota
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

type Palette struct {
	Title, Subtitle, Selected, Cursor, Normal, Dim, Done, Running, Failed, Pending string
}

var flavorPalettes = map[string]Palette{
	"latte": {
		Title:    "#8839ef",
		Subtitle: "#6c6f85",
		Selected: "#40a02b",
		Cursor:   "#dc8a78",
		Normal:   "#4c4f69",
		Dim:      "#9ca0b0",
		Done:     "#40a02b",
		Running:  "#df8e1d",
		Failed:   "#d20f39",
		Pending:  "#9ca0b0",
	},
	"frappe": {
		Title:    "#ca9ee6",
		Subtitle: "#a5adce",
		Selected: "#a6d189",
		Cursor:   "#f2d5cf",
		Normal:   "#c6d0f5",
		Dim:      "#737994",
		Done:     "#a6d189",
		Running:  "#e5c890",
		Failed:   "#e78284",
		Pending:  "#737994",
	},
	"macchiato": {
		Title:    "#c6a0f6",
		Subtitle: "#a5adcb",
		Selected: "#a6da95",
		Cursor:   "#f4dbd6",
		Normal:   "#cad3f5",
		Dim:      "#6e738d",
		Done:     "#a6da95",
		Running:  "#eed49f",
		Failed:   "#ed8796",
		Pending:  "#6e738d",
	},
	"mocha": {
		Title:    "#cba6f7",
		Subtitle: "#a6adc8",
		Selected: "#a6e3a1",
		Cursor:   "#f5e0dc",
		Normal:   "#cdd6f4",
		Dim:      "#6c7086",
		Done:     "#a6e3a1",
		Running:  "#f9e2af",
		Failed:   "#f38ba8",
		Pending:  "#6c7086",
	},
}

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
	Palette          Palette
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
		Palette:        flavorPalettes["mocha"],
	}, nil
}

func defaultFlavors() []string {
	return []string{"latte", "frappe", "macchiato", "mocha"}
}

func defaultAccents() []string {
	return []string{
		"blue", "lavender", "sapphire", "sky", "teal", "green",
		"yellow", "peach", "maroon", "red", "mauve", "pink",
		"flamingo", "rosewater",
	}
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
