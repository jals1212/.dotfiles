package tui

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jals/dotfiles/internal/system"
)

func replaceThemeInDir(dir, theme, flavor, accent string) error {
	return filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && shouldSkipThemeReplaceDir(info.Name()) {
			return filepath.SkipDir
		}
		if !info.IsDir() {
			if shouldSkipThemeReplaceFile(info.Name()) {
				return nil
			}
			return replaceThemeInFile(path, theme, flavor, accent)
		}
		return nil
	})
}

func shouldSkipThemeReplaceDir(name string) bool {
	switch name {
	case ".git", "plugins", "node_modules":
		return true
	default:
		return false
	}
}

func shouldSkipThemeReplaceFile(name string) bool {
	return name == ".DS_Store"
}

func replaceThemeInFile(path, theme, flavor, accent string) error {
	for _, replacement := range themeReplacements(theme, flavor, accent) {
		old, new := replacement[0], replacement[1]
		if err := system.ReplaceInFile(path, old, new); err != nil {
			return err
		}
	}
	return nil
}

func themeReplacements(theme, flavor, accent string) [][2]string {
	if accent == "" {
		accent = defaultAccent
	}
	return [][2]string{
		{"CATPPUCCIN_FLAVOR", flavor},
		{"DOTS_THEME_FLAVOR", theme + "/" + flavor},
		{"DOTS_STARSHIP_PALETTE", starshipPaletteName(theme, flavor)},
		{"DOTS_ATUIN_THEME", atuinThemeName(theme, flavor, accent)},
		{"DOTS_THEME", theme},
		{"DOTS_FLAVOR", flavor},
	}
}

func themeAssetPath(dotfilesDir, tool, theme, themedFile, fallbackFile string) string {
	candidate := filepath.Join(dotfilesDir, "assets", "themes", tool, theme, themedFile)
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	return filepath.Join(dotfilesDir, "assets", "themes", tool, fallbackFile)
}

func starshipPaletteName(theme, flavor string) string {
	return strings.ReplaceAll(theme, "-", "_") + "_" + strings.ReplaceAll(flavor, "-", "_")
}

func atuinThemeName(theme, flavor, accent string) string {
	if theme == "catppuccin" {
		return flavor
	}
	return fmt.Sprintf("%s-%s", theme, flavor)
}

func batThemeFile(theme, flavor string) string {
	if theme == "catppuccin" {
		return fmt.Sprintf("Catppuccin-%s.tmTheme", flavor)
	}
	return fmt.Sprintf("%s-%s.tmTheme", strings.Title(theme), flavor)
}

func batThemeName(theme, flavor string) string {
	if theme == "catppuccin" {
		return "Catppuccin " + flavor
	}
	return strings.Title(theme) + " " + strings.Title(flavor)
}
