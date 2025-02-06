//go:build darwin
// +build darwin

package path

import (
	"path/filepath"
)

// DataHome defines the base directory relative to which user specific data files should be stored.
func DataHome() string {
	return filepath.Join(HomeDir(), "Library")
}

// ConfigHome defines the base directory relative to which user specific configuration files should
// be stored.
func ConfigHome() string {
	return filepath.Join(HomeDir(), "Library", "Preferences")
}

// CacheHome defines the base directory relative to which user specific non-essential data files
// should be stored.
func CacheHome() string {
	return filepath.Join(HomeDir(), "Library", "Caches")
}

// DataHomeWithError defines the base directory relative to which user specific data files should be stored.
func DataHomeWithError() (string, error) {
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, "Library"), nil
}

// ConfigHomeWithError defines the base directory relative to which user specific configuration files should
// be stored.
func ConfigHomeWithError() (string, error) {
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, "Library", "Preferences"), nil
}

// CacheHomeWithError defines the base directory relative to which user specific non-essential data files
// should be stored.
func CacheHomeWithError() (string, error) {
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, "Library", "Caches"), nil
}
