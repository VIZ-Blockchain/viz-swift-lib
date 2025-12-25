// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VIZ",
    products: [
        .library(name: "VIZ", targets: ["VIZ"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/lukaskubanek/OrderedDictionary.git", 
            from: "4.0.0"
        ),
        .package(name: "secp256k1gm", url: "https://github.com/greymass/secp256k1.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "Crypto",
            dependencies: []
        ),
        .target(
            name: "VIZ",
            dependencies: ["Crypto", "OrderedDictionary", "secp256k1gm"]
        ),
        .testTarget(
            name: "UnitTests",
            dependencies: ["VIZ"]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["VIZ"]
        ),
    ]
)
