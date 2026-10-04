// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KclLib",
    products: [
        .library(
            name: "KclLib",
            targets: ["KclLib"]
        ),
        // KclLibAST — typed AST package, mirroring the .NET
        // `KclLib.AST` assembly and the Kotlin `com.kcl.ast.*`
        // package. Lives in its own target so its type names
        // (`FunctionType`, `ListType`, …) don't collide with the
        // protobuf-generated structs of the same name in `KclLib`.
        .library(
            name: "KclLibAST",
            targets: ["KclLibAST"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.27.0"),
    ],
    targets: [
        .systemLibrary(name: "CKclLib"),
        .target(
            name: "KclLib",
            dependencies: [
                "CKclLib",
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            // Sources/CKclLib/lib/libkcl_lib_c.a is NOT in git. It is added
            // by the swift-release workflow at tag time (force-updates the
            // tagged commit) so SPM consumers can `swift build` against a
            // tagged release directly. For local development, run `make
            // cargo` (or `make build`) first.
            //
            // TODO(swift): move to XCFramework + .binaryTarget(url:checksum:)
            // pointed at the GitHub Release so the tag payload stops carrying
            // the binary and cross-platform builds (Linux Swift) work.
            linkerSettings: [
                .unsafeFlags(["-L", "Sources/CKclLib/lib"])
            ]
        ),
        // KclLibAST is a pure Foundation target — no protobuf, no FFI.
        // It just parses the `astJson` string emitted by `ParseFileResult`
        // / `ParseProgramResult` into the typed AST structs.
        .target(
            name: "KclLibAST"
        ),
        .testTarget(
            name: "KclLibTests",
            dependencies: ["KclLib", "KclLibAST"]
        ),
        // KclLibASTTests decodes the checked-in golden capture at
        // `testdata/ast/alignment.json`, so it depends on KclLibAST alone
        // and runs without the cargo-built native library that KclLib links
        // against.
        .testTarget(
            name: "KclLibASTTests",
            dependencies: ["KclLibAST"]
        ),
    ]
)
