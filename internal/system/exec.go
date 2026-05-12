package system

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type ExecResult struct {
	Output   string
	Stderr   string
	Error    error
	ExitCode int
}

// Run executes a shell command
func Run(command string, env []string) *ExecResult {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return &ExecResult{Error: fmt.Errorf("empty command")}
	}

	cmd := exec.Command(parts[0], parts[1:]...)
	if env != nil {
		cmd.Env = append(os.Environ(), env...)
	}
	cmd.Stdin = os.Stdin

	output, err := cmd.CombinedOutput()
	exitCode := 0
	if exitErr, ok := err.(*exec.ExitError); ok {
		exitCode = exitErr.ExitCode()
	}

	return &ExecResult{
		Output:   string(output),
		Stderr:   string(output),
		Error:    err,
		ExitCode: exitCode,
	}
}
