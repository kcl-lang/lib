package path

import (
	"os"
	"os/user"
	"runtime"
	"testing"
)

func TestHomeDirWithError(t *testing.T) {
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

	// test when HOME is not set
	t.Run("EmptyHomeDir", func(t *testing.T) {
		os.Setenv("HOME", "")

		homeDir, err := HomeDirWithError()
		if runtime.GOOS == "windows" {
			if err == nil {
				t.Fatalf("Expected error, got nil")
			}
			if homeDir != "" {
				t.Errorf("Expected home directory to be empty, got %v", homeDir)
			}
		} else {
			usr, _ := user.Current()
			if err != nil {
				t.Fatalf("Expected no error, got %v", err)
			}
			if homeDir != usr.HomeDir {
				t.Errorf("Expected home directory to be %v, got %v", usr.HomeDir, homeDir)
			}
		}
	})
}
