//go:build windows
// +build windows

package path

import "os"

// DataHome defines the base directory relative to which user specific data files should be stored.
func DataHome() string {
	return ConfigHome()
}

// ConfigHome defines the base directory relative to which user specific configuration files should
// be stored.
func ConfigHome() string {
	return os.Getenv("APPDATA")
}

// CacheHome defines the base directory relative to which user specific non-essential data files
// should be stored.
func CacheHome() string {
	return os.Getenv("TEMP")
}
