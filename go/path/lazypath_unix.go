//go:build !windows && !darwin
// +build !windows,!darwin

package path

import (
	"os"
	"path/filepath"
)

// DataHome defines the base directory relative to which user specific data files should be stored.
// It respects the XDG_DATA_HOME environment variable and defaults to ~/.local/share.
func DataHome() string {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome != "" && filepath.IsAbs(dataHome) {
		return dataHome
	}
	return filepath.Join(HomeDir(), ".local", "share")
}

// ConfigHome defines the base directory relative to which user specific configuration files should
// be stored.
// It respects the XDG_CONFIG_HOME environment variable and defaults to ~/.config.
func ConfigHome() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome != "" && filepath.IsAbs(configHome) {
		return configHome
	}
	return filepath.Join(HomeDir(), ".config")
}

// CacheHome defines the base directory relative to which user specific non-essential data files
// should be stored.
// It respects the XDG_CACHE_HOME environment variable and defaults to ~/.cache.
func CacheHome() string {
	cacheHome := os.Getenv("XDG_CACHE_HOME")
	if cacheHome != "" && filepath.IsAbs(cacheHome) {
		return cacheHome
	}
	return filepath.Join(HomeDir(), ".cache")
}

// DataHomeWithError defines the base directory relative to which user specific data files should be stored.
// It respects the XDG_DATA_HOME environment variable and defaults to ~/.local/share.
func DataHomeWithError() (string, error) {
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome != "" && filepath.IsAbs(dataHome) {
		return dataHome, nil
	}
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, ".local", "share"), nil
}

// ConfigHomeWithError defines the base directory relative to which user specific configuration files should
// be stored.
// It respects the XDG_CONFIG_HOME environment variable and defaults to ~/.config.
func ConfigHomeWithError() (string, error) {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome != "" && filepath.IsAbs(configHome) {
		return configHome, nil
	}
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, ".config"), nil
}

// CacheHomeWithError defines the base directory relative to which user specific non-essential data files
// should be stored.
// It respects the XDG_CACHE_HOME environment variable and defaults to ~/.cache.
func CacheHomeWithError() (string, error) {
	cacheHome := os.Getenv("XDG_CACHE_HOME")
	if cacheHome != "" && filepath.IsAbs(cacheHome) {
		return cacheHome, nil
	}
	homeDir, err := HomeDirWithError()
	if err != nil {
		return "", err
	}
	return filepath.Join(homeDir, ".cache"), nil
}
