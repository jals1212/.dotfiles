package system

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
	if err := guardSudoForTests(); err != nil {
		return &ExecResult{Output: err.Error(), Stderr: err.Error(), Error: err, ExitCode: 126}
	}
	return Run("sudo "+command, env)
}

// RunSudoWithLogs executes a sudo command with log streaming
func RunSudoWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	if err := guardSudoForTests(); err != nil {
		if logCallback != nil {
			logCallback(err.Error())
		}
		return &ExecResult{Output: err.Error(), Stderr: err.Error(), Error: err, ExitCode: 126}
	}
	return RunWithLogs("sudo "+command, env, logCallback)
}

func guardSudoForTests() error {
	if !isGoTestBinary() {
		return nil
	}
	if isRunningInContainer() {
		return nil
	}
	return fmt.Errorf("refusing to run sudo during tests outside a Docker/container environment")
}

func isGoTestBinary() bool {
	name := filepath.Base(os.Args[0])
	return strings.HasSuffix(name, ".test")
}

func isRunningInContainer() bool {
	if os.Getenv("container") != "" || os.Getenv("DOTS_IN_CONTAINER") == "1" {
		return true
	}
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	if _, err := os.Stat("/run/.containerenv"); err == nil {
		return true
	}
	data, err := os.ReadFile("/proc/1/cgroup")
	if err != nil {
		return false
	}
	cgroup := string(data)
	return strings.Contains(cgroup, "docker") ||
		strings.Contains(cgroup, "containerd") ||
		strings.Contains(cgroup, "kubepods") ||
		strings.Contains(cgroup, "podman")
}
