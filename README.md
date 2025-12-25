# viz-swift-lib

![Tests badge](https://github.com/VIZ-Blockchain/viz-swift-lib/actions/workflows/tests.yml/badge.svg?branch=master)
[![Swift](https://img.shields.io/badge/Swift-5.5%2B-orange.svg)](https://swift.org)
![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20Linux-blue.svg)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](#license)

VIZ library for the Swift language — build and encode operations, compose transactions, compute digests, and sign them with secp256k1 for the VIZ blockchain.

Installation
------------
Using the [Swift Package Manager](https://swift.org/package-manager/):

In your `Package.swift` just add:

```
dependencies: [
    .package(url: "https://github.com/viz-blockchain/viz-swift-lib.git", .upToNextMinor(from: "0.0.3"))
]
```

and run `swift package update`. Now you can `import VIZ` in your Swift project.

Running tests
-------------

To run all tests simply run `swift test`, this will run both the unit- and integration-tests. To run them separately use the `--filter` flag, e.g. `swift test --filter IntegrationTests`

Developing
----------

Development of the library is best done with Xcode, to generate a `.xcodeproj` you need to run `swift package generate-xcodeproj`.

To enable test coverage display go "Scheme > Manage Schemes..." menu item and edit the "viz-swift-lib" scheme, select the Test configuration and under the Options tab enable "Gather coverage for some targets" and add the `viz-swift-lib` target.

After adding adding more unit tests the `swift test --generate-linuxmain` command has to be run and the XCTestManifest changes committed for the tests to be run on Linux.
