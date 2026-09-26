# KCL Artifact Library for Zig

This repo is under development, PRs welcome!

## Developing

### Prerequisites

+ Zig 0.16.0+
+ `protoc` on `PATH` (the protobuf code generator used to derive the typed
  bindings from `../spec/spec.proto` on every build)

### Build and Test

```shell
zig build test
```
