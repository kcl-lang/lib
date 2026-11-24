package native

import "testing"

func TestLibObjectName(t *testing.T) {
	cases := []struct {
		goos string
		want string
	}{
		{"linux", "libkcl.so"},
		{"freebsd", "libkcl.so"},
		{"darwin", "libkcl.dylib"},
		{"windows", "kcl.dll"},
	}
	for _, tc := range cases {
		if got := libObjectName(tc.goos); got != tc.want {
			t.Errorf("libObjectName(%s) = %s, want %s", tc.goos, got, tc.want)
		}
	}
}
