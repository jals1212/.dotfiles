package system

import (
	"fmt"
	"os"
	"strings"
)

// ApplyBlock writes a sentinel-bracketed block to path.
// The block is bounded by:
//
//	# dots:<sentinel> begin
//	<body>
//	# dots:<sentinel> end
//
// If the block already exists the body is replaced in-place. If it does not
// exist it is appended to the file. The operation is idempotent: calling it
// twice with the same sentinel and body produces exactly one block.
func ApplyBlock(path, sentinel, body string) error {
	begin := "# dots:" + sentinel + " begin"
	end := "# dots:" + sentinel + " end"

	data, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("patch: read %s: %w", path, err)
	}
	text := string(data)

	startIdx := strings.Index(text, begin)
	endIdx := strings.Index(text, end)
	if startIdx != -1 && endIdx != -1 && endIdx > startIdx {
		// Block exists — replace body only.
		newText := text[:startIdx+len(begin)] + "\n" + body + "\n" + text[endIdx:]
		if newText == text {
			return nil
		}
		return os.WriteFile(path, []byte(newText), 0644)
	}

	// Block absent — append.
	var b strings.Builder
	if len(text) > 0 && !strings.HasSuffix(text, "\n") {
		b.WriteByte('\n')
	}
	b.WriteString(begin)
	b.WriteByte('\n')
	b.WriteString(body)
	b.WriteByte('\n')
	b.WriteString(end)
	b.WriteByte('\n')
	newText := text + b.String()
	if newText == text {
		return nil
	}
	return os.WriteFile(path, []byte(newText), 0644)
}

// RemoveBlock removes the sentinel-bracketed block from path. Content outside
// the block is preserved byte-for-byte. If the sentinel is not present the
// function returns without error.
func RemoveBlock(path, sentinel string) error {
	begin := "# dots:" + sentinel + " begin"
	end := "# dots:" + sentinel + " end"

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("patch: read %s: %w", path, err)
	}
	text := string(data)

	startIdx := strings.Index(text, begin)
	endIdx := strings.Index(text, end)
	if startIdx == -1 || endIdx == -1 || endIdx <= startIdx {
		return nil
	}

	// Include the trailing newline after the end marker, if present.
	afterEnd := endIdx + len(end)
	if afterEnd < len(text) && text[afterEnd] == '\n' {
		afterEnd++
	}

	// Strip any leading newline that was inserted before the begin marker.
	leadingNL := startIdx
	if leadingNL > 0 && text[leadingNL-1] == '\n' {
		leadingNL--
	}

	newText := text[:leadingNL] + text[afterEnd:]
	if newText == text {
		return nil
	}
	return os.WriteFile(path, []byte(newText), 0644)
}

// RemoveLegacyMarkers removes a pre-migration block bracketed by the given
// startMarker and endMarker (each appearing on its own line). It mirrors
// RemoveBlock but for the legacy `# CATPPUCCIN_<NAME>_START`/`_END` format.
// Idempotent: no-op when either marker is missing.
func RemoveLegacyMarkers(path, startMarker, endMarker string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("patch: read %s: %w", path, err)
	}
	text := string(data)

	startIdx := strings.Index(text, startMarker)
	endIdx := strings.Index(text, endMarker)
	if startIdx == -1 || endIdx == -1 || endIdx <= startIdx {
		return nil
	}

	afterEnd := endIdx + len(endMarker)
	if afterEnd < len(text) && text[afterEnd] == '\n' {
		afterEnd++
	}

	leadingNL := startIdx
	if leadingNL > 0 && text[leadingNL-1] == '\n' {
		leadingNL--
	}

	newText := text[:leadingNL] + text[afterEnd:]
	if newText == text {
		return nil
	}
	return os.WriteFile(path, []byte(newText), 0644)
}
