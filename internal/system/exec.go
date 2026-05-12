package system

import (
	"bufio"
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

// RunWithLogs executes a shell command and streams stdout/stderr lines to logCallback
func RunWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return &ExecResult{Error: fmt.Errorf("empty command")}
	}

	cmd := exec.Command(parts[0], parts[1:]...)
	if env != nil {
		cmd.Env = append(os.Environ(), env...)
	}
	cmd.Stdin = os.Stdin

	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return &ExecResult{Error: err}
	}
	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return &ExecResult{Error: err}
	}

	if err := cmd.Start(); err != nil {
		return &ExecResult{Error: err}
	}

	var outputBuilder strings.Builder
	var stderrBuilder strings.Builder

	done := make(chan bool, 2)

	go func() {
		scanner := bufio.NewScanner(stdoutPipe)
		for scanner.Scan() {
			line := scanner.Text()
			outputBuilder.WriteString(line)
			outputBuilder.WriteString("\n")
			if logCallback != nil {
				logCallback(line)
			}
		}
		done <- true
	}()

	go func() {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			line := scanner.Text()
			stderrBuilder.WriteString(line)
			stderrBuilder.WriteString("\n")
			if logCallback != nil {
				logCallback(line)
			}
		}
		done <- true
	}()

	<-done
	<-done

	waitErr := cmd.Wait()
	exitCode := 0
	if exitErr, ok := waitErr.(*exec.ExitError); ok {
		exitCode = exitErr.ExitCode()
	}

	return &ExecResult{
		Output:   outputBuilder.String(),
		Stderr:   stderrBuilder.String(),
		Error:    waitErr,
		ExitCode: exitCode,
	}
}

// RunBrewWithLogs executes a brew command with log streaming
func RunBrewWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return RunWithLogs("brew "+command, env, logCallback)
}

// RunSudo executes a command prefixed with sudo
func RunSudo(command string, env []string) *ExecResult {
	return Run("sudo "+command, env)
}

// RunSudoWithLogs executes a sudo command with log streaming
func RunSudoWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return RunWithLogs("sudo "+command, env, logCallback)
}
