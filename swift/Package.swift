// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KclLib",
    products: [
        .library(
            name: "KclLib",
            targets: ["KclLib"]
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
            linkerSettings: [
                .unsafeFlags(["-L", "Sources/CKclLib/lib"])
            ]
        ),
        .testTarget(
            name: "KclLibTests",
            dependencies: ["KclLib"]
        ),
    ]
)
