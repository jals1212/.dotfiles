package system

// Runner abstracts shell command execution for testability.
type Runner interface {
	Run(command string, env []string) *ExecResult
	RunWithLogs(command string, env []string, logCallback func(string)) *ExecResult
	RunBrewWithLogs(command string, env []string, logCallback func(string)) *ExecResult
	RunSudo(command string, env []string) *ExecResult
	RunSudoWithLogs(command string, env []string, logCallback func(string)) *ExecResult
}

// RealRunner is the production implementation that delegates to package functions.
type RealRunner struct{}

func (RealRunner) Run(command string, env []string) *ExecResult {
	return Run(command, env)
}
func (RealRunner) RunWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return RunWithLogs(command, env, logCallback)
}
func (RealRunner) RunBrewWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return RunBrewWithLogs(command, env, logCallback)
}
func (RealRunner) RunSudo(command string, env []string) *ExecResult {
	return RunSudo(command, env)
}
func (RealRunner) RunSudoWithLogs(command string, env []string, logCallback func(string)) *ExecResult {
	return RunSudoWithLogs(command, env, logCallback)
}
