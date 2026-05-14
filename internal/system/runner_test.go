package system

import (
	"fmt"
	"strings"
	"testing"
)

// MockRunner is a test double that returns scripted results.
type MockRunner struct {
	Results map[string]*ExecResult
}

func NewMockRunner() *MockRunner {
	return &MockRunner{Results: make(map[string]*ExecResult)}
}

func (m *MockRunner) Run(command string, env []string) *ExecResult {
	if r, ok := m.Results[command]; ok {
		return r
	}
	return &ExecResult{Error: fmt.Errorf("mock: no result for %q", command)}
}

func (m *MockRunner) RunWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return m.Run(command, env)
}

func (m *MockRunner) RunBrewWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return m.Run("brew "+command, env)
}

func (m *MockRunner) RunSudo(command string, env []string) *ExecResult {
	return m.Run("sudo "+command, env)
}

func (m *MockRunner) RunSudoWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return m.Run("sudo "+command, env)
}

func TestMockRunner(t *testing.T) {
	tests := []struct {
		name      string
		command   string
		result    *ExecResult
		wantErr   bool
		wantOut   string
	}{
		{
			name:    "scripted success",
			command: "echo hello",
			result:  &ExecResult{Output: "hello", ExitCode: 0},
			wantErr: false,
			wantOut: "hello",
		},
		{
			name:    "scripted failure",
			command: "false",
			result:  &ExecResult{Error: fmt.Errorf("exit status 1"), ExitCode: 1},
			wantErr: true,
		},
		{
			name:    "unscripted command returns error",
			command: "unknown-cmd",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			runner := NewMockRunner()
			if tt.result != nil {
				runner.Results[tt.command] = tt.result
			}

			got := runner.Run(tt.command, nil)
			if tt.wantErr && got.Error == nil {
				t.Errorf("expected error, got nil")
			}
			if !tt.wantErr && got.Error != nil {
				t.Errorf("unexpected error = %v", got.Error)
			}
			if tt.wantOut != "" && !strings.Contains(got.Output, tt.wantOut) {
				t.Errorf("Output = %q, want containing %q", got.Output, tt.wantOut)
			}
		})
	}
}

func TestMockRunnerRunWithLogs(t *testing.T) {
	runner := NewMockRunner()
	runner.Results["echo test"] = &ExecResult{Output: "test", ExitCode: 0}

	var lines []string
	got := runner.RunWithLogs("echo test", nil, func(line string) {
		lines = append(lines, line)
	})
	if got.Error != nil {
		t.Errorf("unexpected error: %v", got.Error)
	}
}

func TestMockRunnerBrew(t *testing.T) {
	runner := NewMockRunner()
	runner.Results["brew install foo"] = &ExecResult{Output: "ok", ExitCode: 0}
	got := runner.RunBrewWithLogs("install foo", nil, nil)
	if got.Error != nil {
		t.Errorf("unexpected error: %v", got.Error)
	}
}

func TestMockRunnerSudo(t *testing.T) {
	runner := NewMockRunner()
	runner.Results["sudo apt update"] = &ExecResult{Output: "done", ExitCode: 0}
	got := runner.RunSudo("apt update", nil)
	if got.Error != nil {
		t.Errorf("unexpected error: %v", got.Error)
	}
}

func TestMockRunnerSudoWithLogs(t *testing.T) {
	runner := NewMockRunner()
	runner.Results["sudo ls"] = &ExecResult{Output: "file", ExitCode: 0}
	got := runner.RunSudoWithLogs("ls", nil, nil)
	if got.Error != nil {
		t.Errorf("unexpected error: %v", got.Error)
	}
}
