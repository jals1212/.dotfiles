package system

import "os"

// FileSystem abstracts common filesystem operations for testability.
type FileSystem interface {
	Stat(name string) (os.FileInfo, error)
	ReadFile(name string) ([]byte, error)
	WriteFile(name string, data []byte, perm os.FileMode) error
	MkdirAll(path string, perm os.FileMode) error
	Remove(name string) error
	RemoveAll(path string) error
	ReadDir(name string) ([]os.DirEntry, error)
	UserHomeDir() (string, error)
}

// OSFileSystem is the production implementation using the standard library.
type OSFileSystem struct{}

func (OSFileSystem) Stat(name string) (os.FileInfo, error)         { return os.Stat(name) }
func (OSFileSystem) ReadFile(name string) ([]byte, error)          { return os.ReadFile(name) }
func (OSFileSystem) WriteFile(name string, data []byte, perm os.FileMode) error {
	return os.WriteFile(name, data, perm)
}
func (OSFileSystem) MkdirAll(path string, perm os.FileMode) error { return os.MkdirAll(path, perm) }
func (OSFileSystem) Remove(name string) error                     { return os.Remove(name) }
func (OSFileSystem) RemoveAll(path string) error                  { return os.RemoveAll(path) }
func (OSFileSystem) ReadDir(name string) ([]os.DirEntry, error)   { return os.ReadDir(name) }
func (OSFileSystem) UserHomeDir() (string, error)                 { return os.UserHomeDir() }
