# viz-swift-lib

![Tests badge](https://github.com/VIZ-Blockchain/viz-swift-lib/actions/workflows/tests.yml/badge.svg?branch=master)
[![Swift](https://img.shields.io/badge/Swift-5.5%2B-orange.svg)](https://swift.org)
![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20Linux-blue.svg)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](#license)

**viz-swift-lib** is a low-level, highly flexible Swift library for interacting with the **VIZ blockchain**.

It provides building blocks for:
- creating operations
- composing transactions
- computing transaction digests
- signing transactions with `secp256k1`
- broadcasting transactions to the network

The library does **not impose any architecture** and does not hide protocol details, making it suitable for:
- mobile wallets
- backend services
- bots
- experimental and research projects

---

## Design philosophy

Unlike high-level SDKs, `viz-swift-lib` focuses on:

- **Full control** — you explicitly create operations, transactions, and signatures
- **Composability** — multiple operations can be combined in a single transaction
- **Security** — private keys and signing always remain under your control
- **Cross-platform** — works on Apple platforms and Linux

If you understand how the VIZ blockchain works, this library does not abstract or restrict anything.

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/viz-blockchain/viz-swift-lib.git",
        .upToNextMinor(from: "0.1.0")
    )
]
```

Or in Xcode: File → Add Packages → Enter the repository URL.

## Quick Start

### 1. Initialize the Client

```swift
import VIZ

let client = VIZ.Client(address: URL(string: "https://node.viz.cx")!)
```

### 2. Fetch Account Information

```swift
let request = VIZ.API.GetAccounts(names: ["alice"])
let accounts = try await client.send(request)

if let account = accounts.first {
    print("Balance: \(account.balance)")
    print("Energy: \(account.energy)")
    print("Vesting Shares: \(account.vestingShares)")
}
```

### 3. Create and Sign a Transaction

```swift
// Get dynamic global properties for transaction reference
let props = try await client.send(VIZ.API.GetDynamicGlobalProperties())

// Create a private key from seed
guard let privateKey = VIZ.PrivateKey(seed: "alice" + "active" + "password") else {
    throw Error.invalidKey
}

// Create a transfer operation
let transfer = VIZ.Operation.Transfer(
    from: "alice",
    to: "bob",
    amount: VIZ.Asset(10.0, .viz),
    memo: "Thanks for everything!"
)

// Build the transaction
let transaction = VIZ.Transaction(
    refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
    refBlockPrefix: props.headBlockId.prefix,
    expiration: props.time.addingTimeInterval(60),
    operations: [transfer]
)

// Sign and broadcast
let signedTx = try transaction.sign(usingKey: privateKey)
let broadcast = VIZ.API.BroadcastTransaction(transaction: signedTx)
let confirmation = try await client.send(broadcast)

print("Transaction ID: \(confirmation.id.base58EncodedString() ?? "")")
```

## Common Use Cases

### Award to Another Account

```swift
let award = VIZ.Operation.Award(
    initiator: "alice",
    receiver: "bob",
    energy: 1000,  // 10% energy
    customSequence: 0,
    memo: "Great content!",
    beneficiaries: [
        VIZ.Operation.Beneficiary(account: "charlie", weight: 1000)
    ]
)

let transaction = VIZ.Transaction(
    refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
    refBlockPrefix: props.headBlockId.prefix,
    expiration: props.time.addingTimeInterval(60),
    operations: [award]
)

let signedTx = try transaction.sign(usingKey: regularKey)
```

### Create a New Account

```swift
// Generate keys for the new account
let masterKey = VIZ.PrivateKey(seed: "newuser" + "master" + "password")!
let activeKey = VIZ.PrivateKey(seed: "newuser" + "active" + "password")!
let regularKey = VIZ.PrivateKey(seed: "newuser" + "regular" + "password")!
let memoKey = VIZ.PrivateKey(seed: "newuser" + "memo" + "password")!

let accountCreate = VIZ.Operation.AccountCreate(
    fee: VIZ.Asset(1.0, .viz),
    creator: "alice",
    newAccountName: "newuser",
    master: VIZ.Authority(keyAuths: [VIZ.Authority.Auth(masterKey.createPublic())]),
    active: VIZ.Authority(keyAuths: [VIZ.Authority.Auth(activeKey.createPublic())]),
    regular: VIZ.Authority(keyAuths: [VIZ.Authority.Auth(regularKey.createPublic())]),
    memoKey: memoKey.createPublic(),
    jsonMetadata: ""
)
```

### Delegate Vesting Shares

```swift
let delegate = VIZ.Operation.DelegateVestingShares(
    delegator: "alice",
    delegatee: "bob",
    vestingShares: VIZ.Asset(1000.0, .vests)
)
```

### Fetch Account History

```swift
let history = VIZ.API.GetAccountHistory(
    account: "alice",
    from: -1,
    limit: 100
)

let operations = try await client.send(history)

for item in operations {
    print("Block: \(item.value.block)")
    print("Operation: \(item.value.operation)")
    print("Timestamp: \(item.value.timestamp)")
}
```

## Key Management

### Generate Keys from Seed

```swift
// Generate a private key from account name and password
let privateKey = VIZ.PrivateKey(seed: "username" + "active" + "password")!

// Derive the public key
let publicKey = privateKey.createPublic()

print("Public Key: \(publicKey.address)")
print("Private Key (WIF): \(privateKey.wif)")
```

### Import Keys

```swift
// From WIF format
let privateKey = VIZ.PrivateKey("5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3")!

// From raw bytes
let keyData = Data(/* 33 bytes with network ID */)
let privateKey = VIZ.PrivateKey(keyData)
```

### Sign and Verify Messages

```swift
let message = "Hello VIZ".data(using: .utf8)!.sha256Digest
let signature = try privateKey.sign(message: message)

let publicKey = signature.recover(message: message, prefix: .mainNet)
print("Recovered public key: \(publicKey?.address ?? "none")")
```

## Working with Assets

```swift
// Create assets
let vizTokens = VIZ.Asset(100.5, .viz)        // 100.500 VIZ
let vestingShares = VIZ.Asset(1000.0, .vests) // 1000.000000 VESTS

// Parse from string
let asset = VIZ.Asset("50.000 VIZ")!

// Access amount with proper precision
print(asset.resolvedAmount)  // 50.0
print(asset.description)     // "50.000 VIZ"
```

## Signing URLs

Create delegated signing requests using `viz://` URLs:

```swift
// Create a signing URL with an operation
let transfer = VIZ.Operation.Transfer(
    from: "__signer",
    to: "bob",
    amount: VIZ.Asset(5.0, .viz),
    memo: "Payment"
)

let params = VIZ.VIZURL.Params(
    signer: "alice",
    callback: "https://myapp.com/callback?tx={{id}}&sig={{sig}}",
    noBroadcast: false
)

let signingURL = VIZ.VIZURL(operation: transfer, params: params)!
print(signingURL.description)

// Resolve the URL to a transaction
let options = VIZ.VIZURL.ResolveOptions(
    refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
    refBlockPrefix: props.headBlockId.prefix,
    expiration: props.time.addingTimeInterval(60),
    signer: "alice"
)

let transaction = try signingURL.resolve(with: options)
```

## Advanced Features

### Custom Operations

The library supports all VIZ blockchain operations including:

- Account management (create, update, recovery)
- Witness operations (voting, updates)
- Content operations (custom json, awards)
- Economic operations (transfers, conversions, escrow)
- And many more...

### Binary Encoding

All types conform to `VIZEncodable` for efficient binary serialization:

```swift
let encoder = VIZ.VIZEncoder()
try transaction.binaryEncode(to: encoder)
let binaryData = encoder.data
```

### Authority Management

Define complex signing authorities with weights:

```swift
let authority = VIZ.Authority(
    weightThreshold: 2,
    accountAuths: [
        VIZ.Authority.Auth("alice", weight: 1),
        VIZ.Authority.Auth("bob", weight: 1)
    ],
    keyAuths: [
        VIZ.Authority.Auth(publicKey, weight: 1)
    ]
)
```

## Error Handling

The library uses Swift's structured error handling:

```swift
do {
    let result = try await client.send(request)
} catch VIZ.Client.Error.responseError(let code, let message) {
    print("RPC Error \(code): \(message)")
} catch VIZ.Client.Error.networkError(let message, let error) {
    print("Network Error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Requirements

- Swift 5.5 or later
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+ / Linux

## Dependencies

- [secp256k1](https://github.com/greymass/secp256k1) - ECDSA signatures and secret/public key operations on curve secp256k1
- [OrderedDictionary](https://github.com/lukaskubanek/OrderedDictionary) - Ordered dictionary data structure lightweight implementation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Running tests

To run all tests simply run `swift test`, this will run both the unit- and integration-tests. To run them separately use the `--filter` flag, e.g. `swift test --filter IntegrationTests`

### Developing

Development of the library is best done with Xcode, to generate a `.xcodeproj` you need to run `swift package generate-xcodeproj`.

To enable test coverage display go "Scheme > Manage Schemes..." menu item and edit the "viz-swift-lib" scheme, select the Test configuration and under the Options tab enable "Gather coverage for some targets" and add the `viz-swift-lib` target.

After adding adding more unit tests the `swift test --generate-linuxmain` command has to be run and the XCTestManifest changes committed for the tests to be run on Linux.

## License

This library is available under the MIT license. See the LICENSE file for more info.

## Support

For questions and support, please visit the [VIZ.cx community](https://t.me/viz_cx).
