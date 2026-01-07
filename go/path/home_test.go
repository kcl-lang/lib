package path

import (
	"os"
	"runtime"
	"testing"
)

func TestHomeDirWithError(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Skipping test on Windows")
	}

	originalHome := os.Getenv("HOME")
	defer os.Setenv("HOME", originalHome)

	// test when HOME is set
	t.Run("ValidHomeDir", func(t *testing.T) {
		expectedHome := "/home/testuser"
		os.Setenv("HOME", expectedHome)

		homeDir, err := HomeDirWithError()
		if err != nil {
			t.Fatalf("Expected no error, got %v", err)
		}
		if homeDir != expectedHome {
			t.Errorf("Expected home directory to be %v, got %v", expectedHome, homeDir)
		}
	})
}

func TestXDGDataHome(t *testing.T) {
	if runtime.GOOS == "windows" || runtime.GOOS == "darwin" {
		t.Skip("Skipping test on Windows and Darwin")
	}

	originalHome := os.Getenv("HOME")
	originalXDGDataHome := os.Getenv("XDG_DATA_HOME")
	defer func() {
		os.Setenv("HOME", originalHome)
		os.Setenv("XDG_DATA_HOME", originalXDGDataHome)
	}()

	t.Run("DefaultWithoutEnvVar", func(t *testing.T) {
		os.Setenv("HOME", "/home/testuser")
		os.Unsetenv("XDG_DATA_HOME")

		expected := "/home/testuser/.local/share"
		result := DataHome()
		if result != expected {
			t.Errorf("Expected DataHome to be %v, got %v", expected, result)
		}
	})

	t.Run("RespectsEnvVar", func(t *testing.T) {
		os.Setenv("XDG_DATA_HOME", "/custom/data")

		expected := "/custom/data"
		result := DataHome()
		if result != expected {
			t.Errorf("Expected DataHome to be %v, got %v", expected, result)
		}
	})

	t.Run("IgnoresRelativePathEnvVar", func(t *testing.T) {
		os.Setenv("HOME", "/home/testuser")
		os.Setenv("XDG_DATA_HOME", "relative/path")

		// Should fall back to default when XDG_DATA_HOME is relative
		expected := "/home/testuser/.local/share"
		result := DataHome()
		if result != expected {
			t.Errorf("Expected DataHome to fall back to %v, got %v", expected, result)
		}
	})

	t.Run("IgnoresEmptyEnvVar", func(t *testing.T) {
		os.Setenv("HOME", "/home/testuser")
		os.Setenv("XDG_DATA_HOME", "")

		expected := "/home/testuser/.local/share"
		result := DataHome()
		if result != expected {
			t.Errorf("Expected DataHome to be %v, got %v", expected, result)
		}
	})
}

func TestXDGConfigHome(t *testing.T) {
	if runtime.GOOS == "windows" || runtime.GOOS == "darwin" {
		t.Skip("Skipping test on Windows and Darwin")
	}

	originalHome := os.Getenv("HOME")
	originalXDGConfigHome := os.Getenv("XDG_CONFIG_HOME")
	defer func() {
		os.Setenv("HOME", originalHome)
		os.Setenv("XDG_CONFIG_HOME", originalXDGConfigHome)
	}()

	t.Run("DefaultWithoutEnvVar", func(t *testing.T) {
		os.Setenv("HOME", "/home/testuser")
		os.Unsetenv("XDG_CONFIG_HOME")

		expected := "/home/testuser/.config"
		result := ConfigHome()
		if result != expected {
			t.Errorf("Expected ConfigHome to be %v, got %v", expected, result)
		}
	})

	t.Run("RespectsEnvVar", func(t *testing.T) {
		os.Setenv("XDG_CONFIG_HOME", "/custom/config")

		expected := "/custom/config"
		result := ConfigHome()
		if result != expected {
			t.Errorf("Expected ConfigHome to be %v, got %v", expected, result)
		}
	})
}

func TestXDGCacheHome(t *testing.T) {
	if runtime.GOOS == "windows" || runtime.GOOS == "darwin" {
		t.Skip("Skipping test on Windows and Darwin")
	}

	originalHome := os.Getenv("HOME")
	originalXDGCacheHome := os.Getenv("XDG_CACHE_HOME")
	defer func() {
		os.Setenv("HOME", originalHome)
		os.Setenv("XDG_CACHE_HOME", originalXDGCacheHome)
	}()

	t.Run("DefaultWithoutEnvVar", func(t *testing.T) {
		os.Setenv("HOME", "/home/testuser")
		os.Unsetenv("XDG_CACHE_HOME")

		expected := "/home/testuser/.cache"
		result := CacheHome()
		if result != expected {
			t.Errorf("Expected CacheHome to be %v, got %v", expected, result)
		}
	})

	t.Run("RespectsEnvVar", func(t *testing.T) {
		os.Setenv("XDG_CACHE_HOME", "/custom/cache")

		expected := "/custom/cache"
		result := CacheHome()
		if result != expected {
			t.Errorf("Expected CacheHome to be %v, got %v", expected, result)
		}
	})
}
