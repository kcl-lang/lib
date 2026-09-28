# KclLib Julia binding — pure FFI consumer of the prebuilt libkcl binaries in
# ../go/lib/<platform>/ (no Rust build). Julia is taken from PATH or, on
# machines where it lives outside PATH, from JULIA (see CI) or the default
# juliaup-style location used by this repo's maintainers.

JULIA ?= $(shell command -v julia 2>/dev/null || echo $(HOME)/.juliaup/bin/julia)

.PHONY: all
all: test

# Regenerate the vendored protobuf bindings in src/pb from ../spec/spec.proto.
.PHONY: proto
proto:
	$(JULIA) --project=. hack/gen_pb.jl

.PHONY: test
test:
	$(JULIA) --project=. -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.test()'

# Remove build/precompilation artifacts only; src/pb is checked in and kept.
.PHONY: clean
clean:
	rm -rf Manifest.toml
