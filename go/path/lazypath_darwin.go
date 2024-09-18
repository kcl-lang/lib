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
