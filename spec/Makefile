# Regenerate language bindings from spec.proto.
#
# Runtime compatibility constraints — do not blindly run with any protoc:
# - java and the java side of kotlin: pom pins protobuf-java 4.33.1, which
#   rejects gencode from protoc >= 36 (RuntimeVersion validation and missing
#   LongList APIs). Until the runtime is bumped, hand-add new fields/classes
#   following the existing generated style instead of running --java_out.
# - swift: requires protoc-gen-swift matching the pinned SwiftProtobuf 1.27.x.
#   `brew install swift-protobuf` now ships 1.38+, whose output is
#   incompatible; build protoc-gen-swift 1.27.1 from the swift-protobuf
#   source and strip the Com_Kcl_Api_ type prefix to match the checked-in file.
# - Not covered here: c/ (c/scripts/generate.sh, nanopb),
#   lua/ (lua/hack/generate_pb.lua), zig/ (zig build gen-proto — codegen runs
#   at build time), nodejs/ and wasm/ (hand-written wrappers, update by hand).
run:
	# protoc spec.proto --java_out ../java/src/main/java   # see note above
	# protoc spec.proto --java_out ../kotlin/src/main/java # see note above
	protoc spec.proto --kotlin_out ../kotlin/src/main/kotlin
	protoc spec.proto --pyi_out ../python/kcl_lib/api
	protoc spec.proto --python_out ../python/kcl_lib/api
	protoc spec.proto --go_out ../go/api
	protoc spec.proto --csharp_out ../dotnet/KclLib/api
	# protoc-gen-swift 1.27.x required, see note above
	protoc spec.proto --swift_out=Visibility=Public:../swift/Sources/KclLib
