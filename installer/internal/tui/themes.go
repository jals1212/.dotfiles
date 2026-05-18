package tui

type Palette struct {
	Title, Subtitle, Selected, Cursor, Normal, Dim, Done, Running, Failed, Pending string
	// Syntax color fields used by the live preview on ScreenThemeFlavor.
	// Sourced from upstream editor themes (kanagawa.nvim / catppuccin nvim).
	Keyword, String, Function, Comment, Number, Type string
	// Background is the hex bg color of the flavor; IsLight true when the flavor
	// is a light theme.
	Background string
	IsLight    bool
}

type ThemeDefinition struct {
	Name          string
	DisplayName   string
	Description   string
	DefaultFlavor string
	Flavors       []string
}

const (
	defaultTheme  = "kanagawa"
	defaultFlavor = "dragon"
	defaultAccent = "mauve"
)

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
		Keyword:    "#8839ef",
		String:     "#40a02b",
		Function:   "#1e66f5",
		Comment:    "#9ca0b0",
		Number:     "#fe640b",
		Type:       "#df8e1d",
		Background: "#eff1f5",
		IsLight:    true,
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
		Keyword:    "#ca9ee6",
		String:     "#a6d189",
		Function:   "#8caaee",
		Comment:    "#737994",
		Number:     "#ef9f76",
		Type:       "#e5c890",
		Background: "#303446",
		IsLight:    false,
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
		Keyword:    "#c6a0f6",
		String:     "#a6da95",
		Function:   "#8aadf4",
		Comment:    "#6e738d",
		Number:     "#f5a97f",
		Type:       "#eed49f",
		Background: "#24273a",
		IsLight:    false,
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
		Keyword:    "#cba6f7",
		String:     "#a6e3a1",
		Function:   "#89b4fa",
		Comment:    "#6c7086",
		Number:     "#fab387",
		Type:       "#f9e2af",
		Background: "#1e1e2e",
		IsLight:    false,
	},
}

var themePalettes = map[string]Palette{
	"catppuccin/latte":     flavorPalettes["latte"],
	"catppuccin/frappe":    flavorPalettes["frappe"],
	"catppuccin/macchiato": flavorPalettes["macchiato"],
	"catppuccin/mocha":     flavorPalettes["mocha"],
	"kanagawa/wave": {
		Title:    "#957fb8",
		Subtitle: "#727169",
		Selected: "#98bb6c",
		Cursor:   "#d27e99",
		Normal:   "#dcd7ba",
		Dim:      "#54546d",
		Done:     "#98bb6c",
		Running:  "#e6c384",
		Failed:   "#e82424",
		Pending:  "#727169",
		Keyword:    "#957fb8",
		String:     "#98bb6c",
		Function:   "#7e9cd8",
		Comment:    "#727169",
		Number:     "#d27e99",
		Type:       "#7fb4ca",
		Background: "#1f1f28",
		IsLight:    false,
	},
	"kanagawa/dragon": {
		Title:    "#8992a7",
		Subtitle: "#737c73",
		Selected: "#87a987",
		Cursor:   "#a292a3",
		Normal:   "#c5c9c5",
		Dim:      "#625e5a",
		Done:     "#87a987",
		Running:  "#c4b28a",
		Failed:   "#c4746e",
		Pending:  "#737c73",
		Keyword:    "#957fb8",
		String:     "#87a987",
		Function:   "#8ba4b0",
		Comment:    "#737c73",
		Number:     "#b6927b",
		Type:       "#8ea4a2",
		Background: "#181616",
		IsLight:    false,
	},
	"kanagawa/lotus": {
		Title:    "#624c83",
		Subtitle: "#8a8980",
		Selected: "#6f894e",
		Cursor:   "#b35b79",
		Normal:   "#545464",
		Dim:      "#a09cac",
		Done:     "#6f894e",
		Running:  "#de9800",
		Failed:   "#c84053",
		Pending:  "#8a8980",
		Keyword:    "#624c83",
		String:     "#6f894e",
		Function:   "#4d699b",
		Comment:    "#8a8980",
		Number:     "#b35b79",
		Type:       "#597b75",
		Background: "#f2ecbc",
		IsLight:    true,
	},
}

func defaultThemes() []ThemeDefinition {
	return []ThemeDefinition{
		{
			Name:          "kanagawa",
			DisplayName:   "Kanagawa",
			Description:   "Japanese-inspired palette: wave, dragon, lotus",
			DefaultFlavor: "dragon",
			Flavors:       []string{"wave", "dragon", "lotus"},
		},
		{
			Name:          "catppuccin",
			DisplayName:   "Catppuccin",
			Description:   "Pastel palette: latte, frappé, macchiato, mocha",
			DefaultFlavor: "mocha",
			Flavors:       []string{"latte", "frappe", "macchiato", "mocha"},
		},
	}
}

func defaultFlavors() []string {
	return defaultFlavorsForTheme("catppuccin")
}

func defaultFlavorsForTheme(theme string) []string {
	for _, def := range defaultThemes() {
		if def.Name == theme {
			return append([]string{}, def.Flavors...)
		}
	}
	return defaultFlavorsForTheme(defaultTheme)
}

func defaultFlavorForTheme(theme string) string {
	for _, def := range defaultThemes() {
		if def.Name == theme {
			return def.DefaultFlavor
		}
	}
	return defaultFlavor
}

func paletteFor(theme, flavor string) Palette {
	if p, ok := themePalettes[theme+"/"+flavor]; ok {
		return p
	}
	if p, ok := flavorPalettes[flavor]; ok {
		return p
	}
	return themePalettes[defaultTheme+"/"+defaultFlavor]
}

// FlavorPalette returns the Palette for the given theme/flavor pair.
// Falls back to kanagawa/dragon when the combination is unknown.
func FlavorPalette(theme, flavor string) Palette {
	return paletteFor(theme, flavor)
}

func normalizeThemeFlavor(theme, flavor string) (string, string) {
	if theme == "" {
		theme = defaultTheme
	}
	flavors := defaultFlavorsForTheme(theme)
	if flavor == "" {
		return theme, defaultFlavorForTheme(theme)
	}
	for _, candidate := range flavors {
		if candidate == flavor {
			return theme, flavor
		}
	}
	return theme, defaultFlavorForTheme(theme)
}

func defaultAccents() []string {
	return []string{
		"blue", "lavender", "sapphire", "sky", "teal", "green",
		"yellow", "peach", "maroon", "red", "mauve", "pink",
		"flamingo", "rosewater",
	}
}
