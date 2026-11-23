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
# - kotlin's DSL (`--kotlin_out`) is the opposite case: it must come from the
#   same protoc as the rest of the tree (**36.2**), because protoc 25.5's
#   Kotlin generator emits the pre-1.27 style (`@JvmName` instead of
#   `@kotlin.jvm.JvmName`, no `// NO CHECKED-IN PROTOBUF GENCODE` header) and
#   rewrites every DSL file in the package. protoc 36.2 also renames the
#   `package` field of `GenerateProtoArgs`/`KclModPackage` to `package_` in the
#   DSL, because `package` is a Kotlin keyword; the checked-in stub was
#   hand-written with the backtick form and did not match the generator.
# - swift: requires protoc-gen-swift matching the pinned SwiftProtobuf 1.27.x.
#   `brew install swift-protobuf` now ships 1.38+, whose output is
#   incompatible; build protoc-gen-swift 1.27.1 from the swift-protobuf
#   source and strip the Com_Kcl_Api_ type prefix to match the checked-in file:
#       git clone --depth 1 --branch 1.27.1 https://github.com/apple/swift-protobuf.git
#       cd swift-protobuf && swift build -c release --product protoc-gen-swift
#   With 1.38 installed the diff is a wholesale rewrite.
# - go: the checked-in stub was produced by protoc-gen-go v1.36.10, recorded in
#   its own header. `@latest` will silently bump that; pin it:
#       go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.10
# - php: requires protoc 36.2, the release whose `--php_out` gencode matches
#   the pinned google/protobuf PHP runtime 4.33.x in php/composer.json:
#       protoc --php_out=../php/src/Api -I . spec.proto
#   The gencode lands under `Com/Kcl/Api` + `GPBMetadata` and is vendored with
#   PSR-4 mappings in php/composer.json (see also the pinned-tools note in
#   php/Makefile).
# - dart: `make -C ../dart proto` (protoc-gen-dart from `dart pub global
#   activate protoc_plugin`). protoc-gen-dart 25.x also writes a
#   `spec.pbserver.dart` service stub; this repo dispatches RPCs by name
#   string, so that file is not vendored — delete it after regenerating.
# - julia: `make -C ../julia proto` (ProtoBuf.jl).
# - zig: `cd ../zig && zig build gen-proto` (zig-protobuf's protoc-gen-zig).
# - lua: `make -C ../lua proto` (lua-protobuf's `protoc` module). The blob it
#   writes is not byte-stable across runs — see lua/hack/schema_header.lua.
# - c: `c/scripts/generate.sh` (nanopb, pinned to 0.4.9.1).
# - nodejs/ and wasm/: hand-written wrappers, update by hand.
PROTOC_JAVA = protoc-25.5/bin/protoc
run:
	# $(PROTOC_JAVA) spec.proto --java_out ../kotlin/src/main/java  # raw output, no formatter
	# $(PROTOC_JAVA) spec.proto --java_out ../java/src/main/java    # then: cd ../java && mvn -o formatter:format
	protoc spec.proto --kotlin_out ../kotlin/src/main/kotlin
	protoc spec.proto --pyi_out ../python/kcl_lib/api
	protoc spec.proto --python_out ../python/kcl_lib/api
	protoc spec.proto --go_out ../go/api
	protoc spec.proto --csharp_out ../dotnet/KclLib/api
	protoc spec.proto --ruby_out ../ruby/lib/kcl_lib
	protoc spec.proto --php_out=../php/src/Api -I .
	# protoc-gen-swift 1.27.x required, see note above. The prefix strip keeps
	# the checked-in type names (`ExternalPkg`, not `Com_Kcl_Api_ExternalPkg`).
	protoc spec.proto --swift_out=Visibility=Public:../swift/Sources/KclLib
	sed -e 's|Com_Kcl_Api_||g' ../swift/Sources/KclLib/spec.pb.swift > ../swift/Sources/KclLib/spec.pb.swift.tmp
	mv ../swift/Sources/KclLib/spec.pb.swift.tmp ../swift/Sources/KclLib/spec.pb.swift
