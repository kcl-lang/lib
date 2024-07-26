package env

import "os"

// Enable the fast eval mode.
func EnableFastEvalMode() {
	// Set the fast eval mode for KCL
	os.Setenv("KCL_FAST_EVAL", "1")
}
