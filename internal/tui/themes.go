package tui

type Palette struct {
	Title, Subtitle, Selected, Cursor, Normal, Dim, Done, Running, Failed, Pending string
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
