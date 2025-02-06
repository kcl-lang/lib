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
