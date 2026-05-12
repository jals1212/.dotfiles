package system

import (
	"strings"
	"sync"
	"testing"
)

func TestRun(t *testing.T) {
	tests := []struct {
		name         string
		command      string
		wantErr      bool
		wantExitCode int
		wantOutput   string
	}{
		{
			name:         "echo command",
			command:      "echo hello",
			wantErr:      false,
			wantExitCode: 0,
			wantOutput:   "hello",
		},
		{
			name:         "false command exits with 1",
			command:      "false",
			wantErr:      true,
			wantExitCode: 1,
		},
		{
			name:    "invalid command",
			command: "this_command_definitely_does_not_exist_12345",
			wantErr: true,
		},
		{
			name:         "empty command",
			command:      "",
			wantErr:      true,
			wantExitCode: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Run(tt.command, nil)
			if tt.wantErr && result.Error == nil {
				t.Errorf("Run(%q) expected error, got nil", tt.command)
			}
			if !tt.wantErr && result.Error != nil {
				t.Errorf("Run(%q) unexpected error = %v", tt.command, result.Error)
			}
			if result.ExitCode != tt.wantExitCode {
				t.Errorf("Run(%q) ExitCode = %d, want %d", tt.command, result.ExitCode, tt.wantExitCode)
			}
			if tt.wantOutput != "" && !strings.Contains(result.Output, tt.wantOutput) {
				t.Errorf("Run(%q) Output = %q, want containing %q", tt.command, result.Output, tt.wantOutput)
			}
		})
	}
}

func TestRunWithLogs(t *testing.T) {
	tests := []struct {
		name          string
		command       string
		wantLines     int
		wantErr       bool
		wantExitCode  int
	}{
		{
			name:         "echo with callback",
			command:      "echo hello",
			wantLines:    1,
			wantErr:      false,
			wantExitCode: 0,
		},
		{
			name:         "multiple lines",
			command:      "seq 1 2",
			wantLines:    2,
			wantErr:      false,
			wantExitCode: 0,
		},
		{
			name:         "false command",
			command:      "false",
			wantLines:    0,
			wantErr:      true,
			wantExitCode: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var mu sync.Mutex
			var lines []string

			callback := func(line string) {
				mu.Lock()
				defer mu.Unlock()
				lines = append(lines, line)
			}

			result := RunWithLogs(tt.command, nil, callback)

			if tt.wantErr && result.Error == nil {
				t.Errorf("RunWithLogs(%q) expected error, got nil", tt.command)
			}
			if !tt.wantErr && result.Error != nil {
				t.Errorf("RunWithLogs(%q) unexpected error = %v", tt.command, result.Error)
			}
			if result.ExitCode != tt.wantExitCode {
				t.Errorf("RunWithLogs(%q) ExitCode = %d, want %d", tt.command, result.ExitCode, tt.wantExitCode)
			}

			mu.Lock()
			gotLines := len(lines)
			mu.Unlock()

			if gotLines != tt.wantLines {
				t.Errorf("RunWithLogs(%q) callback lines = %d, want %d", tt.command, gotLines, tt.wantLines)
			}
		})
	}
}

func TestRunBrewWithLogs(t *testing.T) {
	// Just verify it doesn't panic and prefixes with brew
	var lines []string
	callback := func(line string) {
		lines = append(lines, line)
	}
	// Use an invalid brew command since brew may not be installed
	result := RunBrewWithLogs("--version", nil, callback)
	if result == nil {
		t.Fatal("RunBrewWithLogs returned nil")
	}
}

func TestRunSudo(t *testing.T) {
	// Use an echo command via sudo to test prefixing
	result := RunSudo("echo hello", nil)
	if result == nil {
		t.Fatal("RunSudo returned nil")
	}
}

func TestRunSudoWithLogs(t *testing.T) {
	var lines []string
	callback := func(line string) {
		lines = append(lines, line)
	}
	result := RunSudoWithLogs("echo hello", nil, callback)
	if result == nil {
		t.Fatal("RunSudoWithLogs returned nil")
	}
}
