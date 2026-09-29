# kcl_lib Dart binding — pure FFI consumer of the prebuilt libkcl binaries in
# ../go/lib/<platform>/. No Rust build. Protobuf message code under
# lib/src/pb/ is vendored from ../spec/spec.proto and checked in; regenerate
# with `make proto` (requires `protoc` and `protoc-gen-dart` on PATH).
#
# protoc-gen-dart install:
#     dart pub global activate protoc_plugin
#     export PATH="$PATH:$HOME/.pub-cache/bin"
#
# protoc install:
#     brew install protobuf          # macOS
#     apt-get install -y protobuf-compiler  # Debian/Ubuntu

DART ?= $(shell command -v dart 2>/dev/null)

ifeq ($(DART),)
$(error `dart` not found on PATH. Install the Dart SDK from https://dart.dev/get-dart)
endif

SPEC := ../spec/spec.proto
OUT  := lib/src/pb

.PHONY: all
all: test

.PHONY: proto
proto:
	@command -v protoc >/dev/null || (echo "protoc not found; install protobuf-compiler"; exit 1)
	@# Verify protoc-gen-dart is invokable. Git Bash on Windows does not always
	@# surface `.bat` shims to `command -v` (PATHEXT lookup is inconsistent), and
	# `dart pub global activate protoc_plugin` drops `protoc-gen-dart.bat` on
	@# Windows vs. a bare executable on macOS/Linux. Probe in this order so the
	@# matrix stays green on every runner OS:
	@#   1. `command -v protoc-gen-dart`       — picks up the bare name on Unix
	@#                                          and the .bat via PATHEXT on most
	@#                                          Git Bash setups.
	@#   2. `command -v protoc-gen-dart.bat`   — explicit .bat probe.
	@#   3. `[ -f "$(PUB_CACHE)/bin/... ]`     — last-resort file existence
	@#                                          check (`.bat` first on Windows,
	@#                                          bare on Unix). Skips the PATH
	@#                                          lookup entirely, so it works even
	@#                                          when the install step's
	@#                                          `$GITHUB_PATH` export didn't take.
	@command -v protoc-gen-dart >/dev/null \
	  || command -v protoc-gen-dart.bat >/dev/null \
	  || [ -f "$(PUB_CACHE)/bin/protoc-gen-dart.bat" ] \
	  || [ -f "$(PUB_CACHE)/bin/protoc-gen-dart" ] \
	  || (echo "protoc-gen-dart not found; run 'dart pub global activate protoc_plugin' and add \$$PUB_CACHE/bin to PATH (currently PUB_CACHE=$$PUB_CACHE)"; exit 2)
	@mkdir -p $(OUT)
	# Use --proto_path (long form) instead of -I: make's own `-I` flag is for
	# included Makefiles and some CI shells strip `-I<dir>` from recipe lines,
	# which leaves protoc with no include path and aborts with "File does not
	# reside within any path specified using --proto_path (or -I)".
	#
	# --experimental_allow_proto3_optional is a no-op on protoc 3.22+ and
	# required on older versions (Ubuntu 22.04 ships libprotoc 3.21.x).
	protoc --experimental_allow_proto3_optional --proto_path=../spec $(SPEC) --dart_out=$(OUT)
	@# protoc-gen-dart emits `.pb.dart` (messages) and `.pbjson.dart` (descriptor).
	@# It would also emit `.pbgrpc.dart` (gRPC stubs) if invoked with `grpc:`;
	@# we use the message-only form because the native dispatcher routes RPCs
	@# by name string (see c/include/kcl_ffi.h), exactly like the Julia binding.

.PHONY: test
test:
	$(DART) pub get
	$(DART) test test/

# Convenience target for in-tree runs: points KCL_DART_LIB at the
# prebuilt libkcl under ../go/lib/<platform>/ that matches the host.
.PHONY: test-local
test-local:
	@test -n "$$KCL_DART_LIB" || (echo 'KCL_DART_LIB is required for test-local; set it to ../go/lib/<host>/libkcl.{so,dylib,dll}'; exit 1)
	$(MAKE) test

.PHONY: clean
clean:
	rm -rf .dart_tool/
	# Keep pubspec.lock and lib/src/pb/ — both are intentional.