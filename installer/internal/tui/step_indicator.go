package tui

import "strings"

// StepInfo describes a single step in the install funnel.
type StepInfo struct {
	Label string
	ID    Screen
}

// installFunnelSteps returns the canonical funnel step order.
func installFunnelSteps() []StepInfo {
	return []StepInfo{
		{Label: "Theme", ID: ScreenThemeSelect},
		{Label: "Flavor", ID: ScreenFlavorSelect},
		{Label: "Preview", ID: ScreenThemePreview},
		{Label: "Tools", ID: ScreenToolSelect},
		{Label: "Install", ID: ScreenInstalling},
	}
}

// currentStepIndex returns the index of the active funnel step for screens
// that are part of the install funnel, or -1 for off-funnel screens.
func currentStepIndex(screen Screen) int {
	steps := installFunnelSteps()
	// BackupConfirm is part of the install funnel but shares index with ScreenInstalling
	if screen == ScreenBackupConfirm {
		// BackupConfirm sits between ToolSelect (index 3) and Installing (index 4);
		// treat it as index 4 (Install step active).
		return 4
	}
	for i, step := range steps {
		if step.ID == screen {
			return i
		}
	}
	return -1
}

// RenderSteps renders the step indicator line.
// Steps before current are styled done, current is styled active, rest are pending.
// When width > 0 the indicator is centered horizontally.
func RenderSteps(steps []StepInfo, current int, p Palette, width int) string {
	s := getStyles(p)
	parts := make([]string, 0, len(steps))
	for i, step := range steps {
		var dot, label string
		switch {
		case i < current:
			dot = s.stepDone.Render("✓")
			label = s.stepDone.Render(step.Label)
		case i == current:
			dot = s.stepActive.Render("●")
			label = s.stepActive.Render(step.Label)
		default:
			dot = s.stepPending.Render("○")
			label = s.stepPending.Render(step.Label)
		}
		parts = append(parts, dot+" "+label)
	}
	line := strings.Join(parts, s.dim.Render(" → "))
	if width > 0 {
		return CenterHorizontally(line, width)
	}
	return line
}
