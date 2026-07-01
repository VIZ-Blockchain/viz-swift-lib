# viz-swift-lib

![Tests](https://github.com/VIZ-Blockchain/viz-swift-lib/actions/workflows/tests.yml/badge.svg?branch=master)
[![Swift](https://img.shields.io/badge/Swift-5.5%2B-orange.svg)](https://swift.org)
![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20Linux-blue.svg)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](#license)

A low-level, unopinionated Swift library for the **VIZ blockchain**.

`viz-swift-lib` gives you the primitives — operations, transactions, signing, JSON-RPC — and stays out of your way. Good for mobile wallets, backend services, bots, and research projects where you want full control over how the chain is used.

---

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Keys](#keys)
- [Assets](#assets)
- [Common operations](#common-operations)
- [Signing URLs](#signing-urls)
- [Authority management](#authority-management)
- [Error handling](#error-handling)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Full operation coverage** — transfers, awards, account create/update, validator votes, vesting, escrow, recovery, and more
- **Composable transactions** — combine any number of operations in one signed transaction
- **Pure-Swift signing** — `secp256k1` ECDSA, key derivation from seed, WIF import/export
- **Async/await JSON-RPC client** — `actor`-based, `Sendable` types throughout
- **No hidden state** — you decide how to manage keys, sessions, retries, and broadcasting
- **Cross-platform** — Apple platforms and Linux

This is **not** a wallet or a high-level SDK: there is no auto-key-management, no UI, no transaction queue. If you need those, build them on top.

---

## Installation

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/viz-blockchain/viz-swift-lib.git",
        .upToNextMinor(from: "0.1.0")
    )
]
```

Or in Xcode: **File → Add Packages…** and enter the repository URL.

---

## Quick start

A complete signed transfer from one account to another:

```swift
import VIZ

let client = VIZ.Client(address: URL(string: "https://node.viz.cx")!)

// 1. Fetch chain head for the transaction reference block.
let props = try await client.send(VIZ.API.GetDynamicGlobalProperties())

// 2. Derive the signing key (here: from username + role + password).
guard let key = VIZ.PrivateKey(seed: "alice" + "active" + "password") else {
    fatalError("invalid seed")
}

// 3. Build the operation.
let transfer = VIZ.Operation.Transfer(
    from: "alice",
    to: "bob",
    amount: VIZ.Asset(10.0, .viz),
    memo: "Thanks for everything!"
)

// 4. Wrap it in a transaction and sign.
let tx = VIZ.Transaction(
    refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
    refBlockPrefix: props.headBlockId.prefix,
    expiration: props.time.addingTimeInterval(60),
    operations: [transfer]
)
let signed = try tx.sign(usingKey: key)

// 5. Broadcast.
let confirmation = try await client.send(
    VIZ.API.BroadcastTransaction(transaction: signed)
)
print("Transaction ID: \(confirmation.id.base58EncodedString() ?? "")")
```

---

## Keys

### From a seed

```swift
let privateKey = VIZ.PrivateKey(seed: "username" + "active" + "password")!
let publicKey = privateKey.createPublic()

print(publicKey.address)   // e.g. VIZ7…
print(privateKey.wif)      // e.g. 5K…
```

### From WIF or raw bytes

```swift
// WIF
let key = VIZ.PrivateKey("5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3")!

// Raw bytes (32-byte private + 1-byte network ID)
let keyFromBytes = VIZ.PrivateKey(keyData)
```

### Sign and verify a message

```swift
let digest = "Hello VIZ".data(using: .utf8)!.sha256Digest
let signature = try privateKey.sign(message: digest)

let recovered = signature.recover(message: digest, prefix: .mainNet)
print(recovered?.address ?? "could not recover")
```

---

## Assets

```swift
let vizTokens = VIZ.Asset(100.5, .viz)         // "100.500 VIZ"
let shares    = VIZ.Asset(1000.0, .vests)      // "1000.000000 VESTS"

let parsed = VIZ.Asset("50.000 VIZ")!          // parse from string
print(parsed.resolvedAmount)  // 50.0
print(parsed.description)     // "50.000 VIZ"
```

---

## Common operations

### Fetch accounts

```swift
let accounts = try await client.send(VIZ.API.GetAccounts(names: ["alice"]))
if let account = accounts.first {
    print(account.balance)       // VIZ
    print(account.energy)        // current energy bar
    print(account.vestingShares) // VESTS
}
```

### Award another account

```swift
let award = VIZ.Operation.Award(
    initiator: "alice",
    receiver: "bob",
    energy: 1000,            // 10% energy
    customSequence: 0,
    memo: "Great content!",
    beneficiaries: [
        VIZ.Operation.Beneficiary(account: "charlie", weight: 1000)
    ]
)
```

### Create a new account

```swift
let master  = VIZ.PrivateKey(seed: "newuser" + "master"  + "password")!
let active  = VIZ.PrivateKey(seed: "newuser" + "active"  + "password")!
let regular = VIZ.PrivateKey(seed: "newuser" + "regular" + "password")!
let memo    = VIZ.PrivateKey(seed: "newuser" + "memo"    + "password")!

let create = VIZ.Operation.AccountCreate(
    fee: VIZ.Asset(1.0, .viz),
    creator: "alice",
    newAccountName: "newuser",
    master:  VIZ.Authority(keyAuths: [VIZ.Authority.Auth(master.createPublic())]),
    active:  VIZ.Authority(keyAuths: [VIZ.Authority.Auth(active.createPublic())]),
    regular: VIZ.Authority(keyAuths: [VIZ.Authority.Auth(regular.createPublic())]),
    memoKey: memo.createPublic(),
    jsonMetadata: ""
)
```

### Delegate vesting shares

```swift
let delegate = VIZ.Operation.DelegateVestingShares(
    delegator: "alice",
    delegatee: "bob",
    vestingShares: VIZ.Asset(1000.0, .vests)
)
```

### Read account history

```swift
let history = try await client.send(
    VIZ.API.GetAccountHistory(account: "alice", from: -1, limit: 100)
)
for item in history {
    print(item.value.block, item.value.timestamp, item.value.operation)
}
```

---

## Signing URLs

Build delegated signing requests using `viz://` URLs:

```swift
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

// Resolve a received URL back into a signable transaction:
let options = VIZ.VIZURL.ResolveOptions(
    refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
    refBlockPrefix: props.headBlockId.prefix,
    expiration: props.time.addingTimeInterval(60),
    signer: "alice"
)
let resolved = try signingURL.resolve(with: options)
```

---

## Authority management

Compose multi-sig authorities with weighted account- and key-based auths:

```swift
let authority = VIZ.Authority(
    weightThreshold: 2,
    accountAuths: [
        VIZ.Authority.Auth("alice", weight: 1),
        VIZ.Authority.Auth("bob",   weight: 1)
    ],
    keyAuths: [
        VIZ.Authority.Auth(somePublicKey, weight: 1)
    ]
)
```

---

## Error handling

```swift
do {
    let result = try await client.send(request)
} catch let VIZ.Client.Error.responseError(code, message) {
    print("RPC error \(code): \(message)")
} catch let VIZ.Client.Error.networkError(message, _) {
    print("Network error: \(message)")
} catch let VIZ.Client.Error.codingError(message, _) {
    print("Coding error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Requirements

- Swift **5.5** or later
- iOS **13.0+** · macOS **10.15+** · tvOS **13.0+** · watchOS **6.0+** · Linux

### Dependencies

- [secp256k1](https://github.com/greymass/secp256k1) — ECDSA signatures and curve operations
- [OrderedDictionary](https://github.com/lukaskubanek/OrderedDictionary) — lightweight ordered dictionary

---

## Contributing

Contributions are welcome — please open a Pull Request.

### Tests

```bash
swift test                              # unit + integration
swift test --filter UnitTests           # unit only
swift test --filter IntegrationTests    # integration only (requires live node)
```

### Local development

Generate an Xcode project:

```bash
swift package generate-xcodeproj
```

For test coverage in Xcode: **Scheme → Manage Schemes → viz-swift-lib → Test → Options → Gather coverage for some targets**, then add the `viz-swift-lib` target.

After adding unit tests, register them in `Tests/UnitTests/XCTestManifests.swift` so they also run on Linux.

---

## License

MIT — see [LICENSE](LICENSE).

## Support

Questions and discussion: [VIZ.cx community on Telegram](https://t.me/viz_cx).
