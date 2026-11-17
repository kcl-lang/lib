//go:build darwin || freebsd || linux
// +build darwin freebsd linux

package install

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	lib "kcl-lang.io/lib/go/lib"
)

func TestLibFileName(t *testing.T) {
	cases := []struct {
		goos string
		want string
	}{
		{"linux", "libkcl.so"},
		{"freebsd", "libkcl.so"},
		{"darwin", "libkcl.dylib"},
	}
	for _, tc := range cases {
		got, err := libFileName(tc.goos, "kcl")
		if err != nil {
			t.Errorf("libFileName(%s): %v", tc.goos, err)
			continue
		}
		if got != tc.want {
			t.Errorf("libFileName(%s) = %s, want %s", tc.goos, got, tc.want)
		}
	}
	if _, err := libFileName("windows", "kcl"); err == nil {
		t.Fatal("windows is handled by install_lib_windows.go, not the unix installer")
	}
}

func TestMissingPrebuiltLibFreeBSD(t *testing.T) {
	err := missingPrebuiltLib("freebsd")
	if err == nil {
		t.Fatal("expected an error")
	}
	msg := err.Error()
	if !strings.Contains(msg, "hack/build-freebsd-lib.sh") {
		t.Fatalf("freebsd error should point at the build script, got %v", err)
	}
	if strings.Contains(msg, "kclvm_service_new") {
		t.Fatalf("error must not mention the retired symbol, got %v", err)
	}
	linux := missingPrebuiltLib("linux")
	if linux == nil || strings.Contains(linux.Error(), "build-freebsd-lib.sh") {
		t.Fatalf("linux error should stay on the download path, got %v", linux)
	}
}

func TestInstallLibKeepsExistingLibraryWhenEmbedEmpty(t *testing.T) {
	if len(lib.CliLib) != 0 {
		t.Skip("prebuilt libkcl is embedded; re-run with -tags no_libembed")
	}
	dir := t.TempDir()
	name, err := libFileName(runtime.GOOS, "kcl")
	if err != nil {
		t.Fatal(err)
	}
	payload := []byte("not-a-real-library-but-nonzero")
	if err := os.WriteFile(filepath.Join(dir, name), payload, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := installLib(dir, "kcl", false); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(dir, name))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(payload) {
		t.Fatalf("installLib rewrote an existing library: %q", got)
	}
}

func TestInstallLibReportsHowToBuildWhenMissing(t *testing.T) {
	if len(lib.CliLib) != 0 {
		t.Skip("prebuilt libkcl is embedded; re-run with -tags no_libembed")
	}
	err := installLib(t.TempDir(), "kcl", false)
	if err == nil {
		t.Fatal("expected an error when no library is embedded or already installed")
	}
	if runtime.GOOS == "freebsd" && !strings.Contains(err.Error(), "hack/build-freebsd-lib.sh") {
		t.Fatalf("freebsd error should point at the build script, got %v", err)
	}
}
