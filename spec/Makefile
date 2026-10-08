# Regenerate language bindings from spec.proto.
#
# Runtime compatibility constraints — do not blindly run with any protoc:
# - java and the java side of kotlin: pom pins protobuf-java 4.33.1, which
#   rejects gencode from protoc >= 36 (RuntimeVersion validation and missing
#   LongList APIs). The checked-in stubs were produced by protoc **25.5** — the
#   release whose gencode records "Protobuf Java Version: 3.25.5" — so use that,
#   not the 36.x on PATH:
#       gh release download v25.5 --repo protocolbuffers/protobuf \
#          --pattern "protoc-25.5-osx-aarch_64.zip" && unzip -q protoc-25.5-osx-aarch_64.zip
#   kotlin/ checks its stub in as *raw* protoc output (its pom runs no
#   formatter), so `--java_out` alone is the whole pipeline there.
#   java/ additionally needs `mvn -o net.revelc.code.formatter:formatter-maven-plugin:format`,
#   which is already bound to its build and is what produced the 4-space
#   layout. Verified: regenerating java from the pre-change spec and formatting
#   reproduces the checked-in file to within the pre-existing drift.
#   Do NOT "hand-add" classes instead: every message class is backed by an entry
#   in the embedded serialized FileDescriptorProto, so a class added without its
#   descriptor bytes fails at class-init, not at compile.
# - swift: requires protoc-gen-swift matching the pinned SwiftProtobuf 1.27.x.
#   `brew install swift-protobuf` now ships 1.38+, whose output is
#   incompatible; build protoc-gen-swift 1.27.1 from the swift-protobuf
#   source and strip the Com_Kcl_Api_ type prefix to match the checked-in file.
#   With 1.38 installed the diff is a wholesale rewrite, so swift/ is currently
#   hand-added (see the note on each added struct).
# - go: the checked-in stub was produced by protoc-gen-go v1.36.10, recorded in
#   its own header. `@latest` will silently bump that; pin it:
#       go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.10
# - php: requires protoc 36.2, the release whose `--php_out` gencode matches
#   the pinned google/protobuf PHP runtime 4.33.x in php/composer.json:
#       protoc --php_out=../php/src/Api -I . spec.proto
#   The gencode lands under `Com/Kcl/Api` + `GPBMetadata` and is vendored with
#   PSR-4 mappings in php/composer.json (see also the pinned-tools note in
#   php/Makefile).
# - Not covered here: c/ (c/scripts/generate.sh, nanopb — it git-clones nanopb
#   and needs network), lua/ (lua/hack/generate_pb.lua), zig/ (zig build
#   gen-proto — codegen runs at build time), nodejs/ and wasm/ (hand-written
#   wrappers, update by hand).
PROTOC_JAVA = protoc-25.5/bin/protoc
run:
	# $(PROTOC_JAVA) spec.proto --java_out ../kotlin/src/main/java  # raw output, no formatter
	# $(PROTOC_JAVA) spec.proto --java_out ../java/src/main/java    # then: cd ../java && mvn -o formatter:format
	protoc spec.proto --kotlin_out ../kotlin/src/main/kotlin
	protoc spec.proto --pyi_out ../python/kcl_lib/api
	protoc spec.proto --python_out ../python/kcl_lib/api
	protoc spec.proto --go_out ../go/api
	protoc spec.proto --csharp_out ../dotnet/KclLib/api
	# protoc-gen-swift 1.27.x required, see note above
	protoc spec.proto --swift_out=Visibility=Public:../swift/Sources/KclLib
