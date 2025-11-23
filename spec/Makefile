run:
	protoc spec.proto --java_out ../java/src/main/java
	protoc spec.proto --java_out ../kotlin/src/main/java --kotlin_out ../kotlin/src/main/kotlin
	protoc spec.proto --pyi_out ../python/kcl_lib/api
	protoc spec.proto --python_out ../python/kcl_lib/api
	protoc spec.proto --go_out ../go/api
	protoc spec.proto --csharp_out ../dotnet/KclLib/api
	# brew install swift-protobuf
	protoc spec.proto --swift_out=Visibility=Public:../swift/Sources/KclLib
