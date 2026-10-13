//go:build no_libembed
// +build no_libembed

package lib

// CliLib is empty in this build. The prebuilt libkcl binaries are not
// vendored on the development branches (see docs/lib-vendoring.md), so the
// //go:embed variants of this file — which one is selected depends on the
// host GOOS/GOARCH — cannot be compiled without them.
//
// Build with `-tags no_libembed` when you only need to type-check or vet the
// tree. To actually run the SDK, fetch the binary first:
//
//	hack/download-libs.sh
//
// or build from a release/* branch or tag, where the binaries are vendored.
var CliLib []byte
