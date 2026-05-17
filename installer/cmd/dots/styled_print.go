package main

import (
	"fmt"
	"os"

	"github.com/jals/dotfiles/internal/tui"
)

// subcommandPalette resolves the active palette from DOTS_THEME / DOTS_FLAVOR
// env vars, falling back to kanagawa/dragon.
func subcommandPalette() tui.Palette {
	theme := envOrDefault("DOTS_THEME", "kanagawa")
	flavor := envOrDefault("DOTS_FLAVOR", "dragon")
	return tui.FlavorPalette(theme, flavor)
}

// subcommandHeader returns the skull-glyph header line for the given subcommand name.
// The skull glyph is 󰚌 (U+F068C, nf-md-skull), followed by two spaces, then "dots <name>".
func subcommandHeader(p tui.Palette, name string) string {
	s := tui.SubcommandStylesFor(p)
	return s.Title.Render("󰚌  dots " + name)
}

// subcommandPassRow returns a styled pass row: "✓ <name>".
func subcommandPassRow(p tui.Palette, name string) string {
	s := tui.SubcommandStylesFor(p)
	return s.Done.Render("✓") + " " + s.Normal.Render(name)
}

// subcommandFailRow returns a styled fail row: "✗ <name>: <err>".
func subcommandFailRow(p tui.Palette, name string, err error) string {
	s := tui.SubcommandStylesFor(p)
	return s.Failed.Render("✗") + " " + s.Normal.Render(name+": ") + s.Failed.Render(err.Error())
}

// subcommandStepRow returns a styled step row for dots update.
// done=false uses dim styling (in-progress); done=true uses done color.
func subcommandStepRow(p tui.Palette, name string, done bool) string {
	s := tui.SubcommandStylesFor(p)
	if done {
		return s.Done.Render("✓") + " " + s.Subtitle.Render(name)
	}
	return s.Dim.Render("…") + " " + s.Subtitle.Render(name)
}

// subcommandSummary returns the final summary line for dots doctor.
// passed=true → done style; passed=false → failed style with issue count.
func subcommandSummary(p tui.Palette, passed bool, n int) string {
	s := tui.SubcommandStylesFor(p)
	if passed {
		return s.Done.Render("✓ All doctor checks passed")
	}
	return s.Failed.Render(fmt.Sprintf("✗ Doctor found %d issue(s)", n))
}

// subcommandUpdateSummary returns the summary line for dots update.
func subcommandUpdateSummary(p tui.Palette) string {
	s := tui.SubcommandStylesFor(p)
	return s.Done.Render("✓ Configs updated")
}

// subcommandDimRow returns a dim info row (e.g. "Dotfiles: <path>").
func subcommandDimRow(p tui.Palette, text string) string {
	s := tui.SubcommandStylesFor(p)
	return s.Dim.Render(text)
}

// printLine writes a styled line to stdout.
func printLine(line string) {
	fmt.Fprintln(os.Stdout, line)
}
