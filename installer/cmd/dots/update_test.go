package main

import (
	"strings"
	"testing"

	"github.com/jals/dotfiles/internal/tui"
)

// TestSubcommandUpdateStyledOutput verifies that the styled update output primitives
// produce the expected header, step rows, and summary lines.
// The real deploy steps require a live filesystem and are covered by e2e tests.
func TestSubcommandUpdateStyledOutput(t *testing.T) {
	p := tui.FlavorPalette("kanagawa", "dragon")

	header := subcommandHeader(p, "update")
	if !strings.Contains(header, "dots update") {
		t.Errorf("subcommandHeader: missing 'dots update', got: %q", header)
	}

	deployRow := subcommandStepRow(p, "Deploying configs", true)
	if !strings.Contains(deployRow, "Deploying configs") {
		t.Errorf("subcommandStepRow: missing 'Deploying configs', got: %q", deployRow)
	}
	if !strings.Contains(deployRow, "✓") {
		t.Errorf("subcommandStepRow(done=true): missing '✓', got: %q", deployRow)
	}

	pendingRow := subcommandStepRow(p, "Deploying configs", false)
	if !strings.Contains(pendingRow, "Deploying configs") {
		t.Errorf("subcommandStepRow(done=false): missing 'Deploying configs', got: %q", pendingRow)
	}

	manifestRow := subcommandStepRow(p, "Writing manifest", true)
	if !strings.Contains(manifestRow, "Writing manifest") {
		t.Errorf("subcommandStepRow: missing 'Writing manifest', got: %q", manifestRow)
	}

	summary := subcommandUpdateSummary(p)
	if !strings.Contains(summary, "Configs updated") {
		t.Errorf("subcommandUpdateSummary: missing 'Configs updated', got: %q", summary)
	}
	if !strings.Contains(summary, "✓") {
		t.Errorf("subcommandUpdateSummary: missing '✓', got: %q", summary)
	}
}

func TestSubcommandDimRow(t *testing.T) {
	p := tui.FlavorPalette("kanagawa", "dragon")
	dotfilesPath := "/Users/test/.dotfiles"
	row := subcommandDimRow(p, "Dotfiles: "+dotfilesPath)
	if !strings.Contains(row, "Dotfiles: "+dotfilesPath) {
		t.Errorf("subcommandDimRow: missing path text, got: %q", row)
	}
}

func TestSubcommandPaletteFallback(t *testing.T) {
	// With no env vars set (or unknown theme/flavor), FlavorPalette returns the
	// kanagawa/dragon default. Verify we get a non-zero palette.
	p := tui.FlavorPalette("", "")
	if p.Done == "" {
		t.Error("FlavorPalette fallback returned empty Done color")
	}
	if p.Failed == "" {
		t.Error("FlavorPalette fallback returned empty Failed color")
	}
}
