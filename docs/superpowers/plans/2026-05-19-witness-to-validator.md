# witness → validator Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename "witness" terminology to "validator" across Swift types, fields, and JSON wire format, with one-cycle backward compat (dual-JSON decode + Swift-source deprecated aliases).

**Architecture:** For each renamed struct, rename the Swift identifier, add a `@available(*, deprecated, renamed:)` typealias for the old name, and (when JSON keys are renamed) write a manual `init(from:)` that decodes the new key with a fallback to the old key. Encoders always emit new keys. Binary wire format is unchanged.

**Tech Stack:** Swift 5+, Swift Package Manager, XCTest, Foundation Codable.

**Spec:** `docs/superpowers/specs/2026-05-19-witness-to-validator-design.md`

**File map:**

| File | Change |
|---|---|
| `Sources/VIZ/Operation.swift` | Rename 5 op structs, 5 `OperationId` cases, dispatch sites; 2 structs get manual `init(from:)` for inner-field dual decode; add deprecated typealiases. |
| `Sources/VIZ/Block.swift` | Rename `witness` / `witnessSignature` on `_BlockHeader`, `BlockHeader`, `SignedBlockHeader`, `SignedBlock`; manual `init(from:)` for the two header types with `legacyWitness` / `legacyWitnessSignature` CodingKeys; deprecated computed-property aliases. |
| `Sources/VIZ/API.swift` | Rename 2 fields on `DynamicGlobalProperties` and 3 fields on `ExtendedAccount`; manual `init(from:)` for both with legacy CodingKeys; deprecated computed-property aliases. |
| `Sources/VIZ/Client.swift` | Update namespace-mapping switch arm to accept both old and new `*_witness*` / `*_validator*` method names, routing all to `validator_api`. |
| `Tests/UnitTests/Operation.swift` | Rename 5 existing tests + JSON string literals; add legacy-decode tests + an `OperationId` dual-decode test. |
| `Tests/UnitTests/Block.swift` | Update fixture + assertion property names; add a sibling fixture with new JSON keys and a legacy-key decode test. |
| `Tests/UnitTests/API.swift` | Rename `ExtendedAccount` init labels; add legacy-decode tests for both API types. |
| `Tests/UnitTests/DeprecatedAliases.swift` (new) | Compile-smoke test referencing each deprecated typealias/property/init once. |
| `Tests/UnitTests/XCTestManifests.swift` | Update test names; add new test entries; add `DeprecatedAliasesTest` registration. |

**Conventions used throughout the plan:**

- Each task ends with a commit. Commit messages follow Conventional Commits (`feat:`, `refactor:`, `test:`) consistent with the project's recent history.
- "Run all tests" means: `swift test --filter UnitTests` from the repo root. The repo's CI already filters to `UnitTests`; integration tests use the live node and are not part of the per-task loop.
- Expected output is described, not shown verbatim — Swift test output is verbose. Look for `Test Suite 'UnitTests.xctest' passed` at the end.
- Inside `Sources/VIZ/Operation.swift`, all renamed types live inside `extension Operation { ... }`. Use the existing structure of the file — do not add new files.

---

## Task 1: Rename `OperationId` cases and dispatch sites; add dual-string decode

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (around lines 976–1097 for the enum; lines 1112–1267 for `AnyOperation` dispatch)
- Test: `Tests/UnitTests/Operation.swift` (add a new test method at end of `OperationTest`)

**Context:** `OperationId` is a `fileprivate` enum whose case name is the JSON op-name string (encode uses `"\(self)"`). Renaming the case changes what the encoder emits. The `init(from:)` string-switch maps the JSON string to the case — we add dual-string entries so old names decode to the new case. After this task, `AnyOperation` encoders emit new op names; decoders accept both old and new names. The 5 underlying Swift struct types (`Operation.WitnessUpdate`, etc.) are still old names; they get renamed in Tasks 2–6.

- [ ] **Step 1: Write the failing dual-decode test**

Open `Tests/UnitTests/Operation.swift` and append to `OperationTest` (before the closing brace of the class):

```swift
    func testOperationId_acceptsLegacyAndNewNames() {
        // Each pair: (legacy op_id string, new op_id string). Both should decode to the same
        // Swift type (still using the pre-rename type names — those get renamed in later tasks).
        let cases: [(String, OperationType.Type)] = [
            ("witness_update",         Operation.WitnessUpdate.self),
            ("account_witness_vote",   Operation.AccountWitnessVote.self),
            ("account_witness_proxy",  Operation.AccountWitnessProxy.self),
            ("shutdown_witness",       Operation.ShutdownWitness.self),
            ("witness_reward",         Operation.WitnessReward.self),
        ]
        let bodies = [
            "{\"owner\":\"alice\",\"url\":\"\",\"block_signing_key\":\"VIZ1111111111111111111111111111111114T1Anm\",\"props\":{},\"fee\":\"0.000 VIZ\"}",
            "{\"account\":\"alice\",\"witness\":\"bob\",\"approve\":true}",
            "{\"account\":\"alice\",\"proxy\":\"bob\"}",
            "{\"owner\":\"alice\"}",
            "{\"witness\":\"alice\",\"shares\":\"0.500000 VESTS\"}",
        ]
        let newNames = [
            "validator_update",
            "account_validator_vote",
            "account_validator_proxy",
            "shutdown_validator",
            "validator_reward",
        ]
        for ((legacy, expectedType), body) in zip(cases, bodies) {
            let wrapped = "[\"\(legacy)\",\(body)]"
            do {
                let any = try TestDecode(AnyOperation.self, json: wrapped)
                XCTAssertTrue(type(of: any.operation) == expectedType,
                              "Legacy name \(legacy) decoded to \(type(of: any.operation)), expected \(expectedType)")
            } catch {
                XCTFail("Legacy decode of \(legacy) failed: \(error)")
            }
        }
        for ((newName, expectedType), body) in zip(zip(newNames, cases.map { $0.1 }), bodies) {
            let wrapped = "[\"\(newName)\",\(body)]"
            do {
                let any = try TestDecode(AnyOperation.self, json: wrapped)
                XCTAssertTrue(type(of: any.operation) == expectedType,
                              "New name \(newName) decoded to \(type(of: any.operation)), expected \(expectedType)")
            } catch {
                XCTFail("New-name decode of \(newName) failed: \(error)")
            }
        }
    }
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `swift test --filter UnitTests.OperationTest/testOperationId_acceptsLegacyAndNewNames`
Expected: FAIL — the new-name decode loop throws because `"validator_update"` etc. fall into `OperationId.init(from:)`'s `default: self = .unknown` branch, so `AnyOperation` decodes them to `Operation.Unknown()`.

- [ ] **Step 3: Rename the 5 `OperationId` cases**

In `Sources/VIZ/Operation.swift`, in the `OperationId` enum definition (~lines 976–1037), rename the 5 cases. Keep the raw integer values exactly the same:

```swift
case validator_update = 6
case account_validator_vote = 7
case account_validator_proxy = 8
// ... rest unchanged ...
case shutdown_validator = 30
// ... rest unchanged ...
case validator_reward = 42
```

- [ ] **Step 4: Update `OperationId.init(from:)` string switch to accept both names**

In the same enum's `init(from:)` (~lines 1039–1087), replace each of the 5 affected `case` lines with a dual-string version:

```swift
case "witness_update", "validator_update": self = .validator_update
case "account_witness_vote", "account_validator_vote": self = .account_validator_vote
case "account_witness_proxy", "account_validator_proxy": self = .account_validator_proxy
case "shutdown_witness", "shutdown_validator": self = .shutdown_validator
case "witness_reward", "validator_reward": self = .validator_reward
```

Leave the encode function (`"\(self)"`) untouched — it now emits the new name automatically.

- [ ] **Step 5: Update dispatch sites in `AnyOperation.init(from:)`**

In `Sources/VIZ/Operation.swift` around lines 1124, 1125, 1126, 1140, 1143, change the case patterns to the new enum case names (the `Operation.WitnessUpdate.self` type references stay old for now — they get renamed in Tasks 2–6):

```swift
case .validator_update:        op = try container.decode(Operation.WitnessUpdate.self)
case .account_validator_vote:  op = try container.decode(Operation.AccountWitnessVote.self)
case .account_validator_proxy: op = try container.decode(Operation.AccountWitnessProxy.self)
// ... other lines unchanged ...
case .shutdown_validator:      op = try container.decode(Operation.ShutdownWitness.self)
// ...
case .validator_reward:        op = try container.decode(Operation.WitnessReward.self)
```

- [ ] **Step 6: Update dispatch sites in `AnyOperation.encode(to:)`**

In the same file around lines 1207–1215, change the 3 non-virtual dispatch cases (`WitnessUpdate`, `AccountWitnessVote`, `AccountWitnessProxy`) to encode the new `OperationId` case:

```swift
case let op as Operation.WitnessUpdate:
    try container.encode(OperationId.validator_update)
    try container.encode(op)
case let op as Operation.AccountWitnessVote:
    try container.encode(OperationId.account_validator_vote)
    try container.encode(op)
case let op as Operation.AccountWitnessProxy:
    try container.encode(OperationId.account_validator_proxy)
    try container.encode(op)
```

(The virtual ops `ShutdownWitness` and `WitnessReward` are not in the encode switch — they're decode-only.)

- [ ] **Step 7: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — including the new `testOperationId_acceptsLegacyAndNewNames`. The existing 5 witness-op round-trip and virtual-decode tests still pass because:
- their fixture `opIdName` values (`"witness_update"`, etc.) are still accepted by the dual-string decoder,
- the body JSON content is unchanged at this point,
- AnyOperation's encoder now emits the new op name, but `roundTrip()` only tests AnyOperation **decode**, not encode.

- [ ] **Step 8: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename OperationId witness cases to validator; accept both names"
```

---

## Task 2: Rename `Operation.WitnessUpdate` → `Operation.ValidatorUpdate`

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (struct at line 217; dispatch at lines 1124, 1207)
- Test: `Tests/UnitTests/Operation.swift` (rename `testRoundTrip_witnessUpdate` at line 207)

**Context:** No inner field renames here — just the Swift type name (and therefore the deprecated typealias). The struct uses auto-synth Codable; no manual `init(from:)` needed.

- [ ] **Step 1: Update the existing round-trip test to use new names**

In `Tests/UnitTests/Operation.swift`, replace the test (around lines 207–222):

```swift
    func testRoundTrip_validatorUpdate() {
        let signingKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let fx = OperationFixture(
            value: Operation.ValidatorUpdate(
                owner: "alice",
                url: "https://example.com",
                blockSigningKey: signingKey,
                props: Operation.ValidatorUpdate.Properties(),
                fee: Asset(0, .viz)
            ),
            json: "{\"owner\":\"alice\",\"url\":\"https:\\/\\/example.com\",\"block_signing_key\":\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",\"props\":{},\"fee\":\"0.000 VIZ\"}",
            binary: Data("05616c6963651368747470733a2f2f6578616d706c652e636f6d03c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b00000000000000000356495a00000000"),
            opIdName: "validator_update"
        )
        roundTrip(fx)
    }
```

- [ ] **Step 2: Run the test and verify it fails to compile**

Run: `swift test --filter UnitTests.OperationTest/testRoundTrip_validatorUpdate`
Expected: BUILD FAILED — `Operation.ValidatorUpdate` is undefined.

- [ ] **Step 3: Rename the struct in `Sources/VIZ/Operation.swift`**

Around line 216–244, change the struct name (the body stays identical):

```swift
    /// Registers or updates validators.
    public struct ValidatorUpdate: OperationType, Equatable {
        /// Validator chain properties.
        public struct Properties: VIZCodable, Equatable, Sendable {
//            public var accountCreationFee: Asset
//            public var maximumBlockSize: UInt32
//            public var sbdInterestRate: UInt16
        }

        public var owner: String
        public var url: String
        public var blockSigningKey: PublicKey
        public var props: Properties
        public var fee: Asset

        public init(
            owner: String,
            url: String,
            blockSigningKey: PublicKey,
            props: Properties,
            fee: Asset
        ) {
            self.owner = owner
            self.url = url
            self.blockSigningKey = blockSigningKey
            self.props = props
            self.fee = fee
        }
    }
```

- [ ] **Step 4: Update the dispatch sites**

In `AnyOperation.init(from:)` around line 1124:

```swift
        case .validator_update: op = try container.decode(Operation.ValidatorUpdate.self)
```

In `AnyOperation.encode(to:)` around line 1207:

```swift
        case let op as Operation.ValidatorUpdate:
            try container.encode(OperationId.validator_update)
            try container.encode(op)
```

- [ ] **Step 5: Add a deprecated typealias for source compatibility**

At the very end of `Sources/VIZ/Operation.swift` (after the last existing `extension Operation.CommentOptions.Extension { ... }` block, near the end of the file), add a new extension block. (Subsequent tasks will append more typealiases to this same block.)

```swift
// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension Operation {
    @available(*, deprecated, renamed: "ValidatorUpdate")
    public typealias WitnessUpdate = ValidatorUpdate
}
```

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — all 108+ existing tests plus the renamed `testRoundTrip_validatorUpdate` and the dual-decode test from Task 1. The deprecated typealias keeps any incidental old-name reference compiling (with a warning).

- [ ] **Step 7: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename Operation.WitnessUpdate to ValidatorUpdate"
```

---

## Task 3: Rename `Operation.AccountWitnessVote` → `Operation.AccountValidatorVote`; rename inner `witness` field → `validator`; add dual-key decode

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (struct at line 247; dispatch at lines 1125, 1210; deprecated-aliases block from Task 2)
- Test: `Tests/UnitTests/Operation.swift` (rename `testRoundTrip_accountWitnessVote` at line 224; add a legacy-decode test)

**Context:** This is the first task with an inner-field rename. The new struct needs a manual `init(from:)` with a `legacyWitness = "witness"` CodingKey case that's tried only as fallback when `"validator"` is absent. The body JSON does **not** flow through `convertFromSnakeCase` (Operation bodies have flat lowercase keys), so the CodingKey raw values are the literal JSON key names. The struct also keeps a deprecated `witness` computed property and a deprecated init overload for Swift-source compat.

- [ ] **Step 1: Update existing test + add new legacy-decode test**

In `Tests/UnitTests/Operation.swift`, replace the test around lines 224–232 and add a new legacy-decode test right below it:

```swift
    func testRoundTrip_accountValidatorVote() {
        let fx = OperationFixture(
            value: Operation.AccountValidatorVote(account: "alice", validator: "witness1", approve: true),
            json: "{\"account\":\"alice\",\"validator\":\"witness1\",\"approve\":true}",
            binary: Data("05616c696365087769746e6573733101"),
            opIdName: "account_validator_vote"
        )
        roundTrip(fx)
    }

    func testDecode_accountValidatorVote_legacyWitnessKey() {
        let legacyJSON = "{\"account\":\"alice\",\"witness\":\"bob\",\"approve\":true}"
        let expected = Operation.AccountValidatorVote(account: "alice", validator: "bob", approve: true)
        AssertDecodes(json: legacyJSON, expected)
    }
```

- [ ] **Step 2: Run tests and verify build failure**

Run: `swift test --filter UnitTests.OperationTest/testRoundTrip_accountValidatorVote`
Expected: BUILD FAILED — `Operation.AccountValidatorVote` is undefined.

- [ ] **Step 3: Rename the struct and add dual-key `init(from:)`**

Replace the existing struct in `Sources/VIZ/Operation.swift` (around lines 246–257) with:

```swift
    /// Votes for a validator.
    public struct AccountValidatorVote: OperationType, Equatable {
        public var account: String
        public var validator: String
        public var approve: Bool

        public init(account: String, validator: String, approve: Bool) {
            self.account = account
            self.validator = validator
            self.approve = approve
        }

        enum CodingKeys: String, CodingKey {
            case account, validator, approve
            case legacyWitness = "witness"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.account = try c.decode(String.self, forKey: .account)
            self.approve = try c.decode(Bool.self,   forKey: .approve)
            self.validator = (try? c.decode(String.self, forKey: .validator))
                          ?? (try c.decode(String.self, forKey: .legacyWitness))
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(account,   forKey: .account)
            try c.encode(validator, forKey: .validator)
            try c.encode(approve,   forKey: .approve)
        }
    }
```

- [ ] **Step 4: Update the dispatch sites**

In `AnyOperation.init(from:)` around line 1125:

```swift
        case .account_validator_vote: op = try container.decode(Operation.AccountValidatorVote.self)
```

In `AnyOperation.encode(to:)` around line 1210:

```swift
        case let op as Operation.AccountValidatorVote:
            try container.encode(OperationId.account_validator_vote)
            try container.encode(op)
```

- [ ] **Step 5: Add deprecated typealias and deprecated init overload**

Append to the `extension Operation { ... }` deprecated-aliases block at the end of the file (created in Task 2):

```swift
    @available(*, deprecated, renamed: "AccountValidatorVote")
    public typealias AccountWitnessVote = AccountValidatorVote
```

Then inside `Operation.AccountValidatorVote` add a deprecated init overload (after the canonical init). Put it inline in the struct body so the old call-site `Operation.AccountWitnessVote(account:witness:approve:)` (typealiased) still type-checks with the old argument label:

```swift
        @available(*, deprecated, message: "Use init(account:validator:approve:)")
        public init(account: String, witness: String, approve: Bool) {
            self.init(account: account, validator: witness, approve: approve)
        }
```

And a deprecated computed property aliasing `witness` → `validator`:

```swift
        @available(*, deprecated, renamed: "validator")
        public var witness: String {
            get { validator }
            set { validator = newValue }
        }
```

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — the renamed round-trip test, the new legacy-decode test, and all other existing tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename AccountWitnessVote to AccountValidatorVote with dual-key decode"
```

---

## Task 4: Rename `Operation.AccountWitnessProxy` → `Operation.AccountValidatorProxy`

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (struct at line 260; dispatch at lines 1126, 1213; deprecated-aliases block)
- Test: `Tests/UnitTests/Operation.swift` (rename `testRoundTrip_accountWitnessProxy` at line 234)

**Context:** No inner field rename — only the struct name (and OperationId case, already done in Task 1) changes. No manual `init(from:)` needed.

- [ ] **Step 1: Update the existing test**

In `Tests/UnitTests/Operation.swift`, replace the test around lines 234–241:

```swift
    func testRoundTrip_accountValidatorProxy() {
        let fx = OperationFixture(
            value: Operation.AccountValidatorProxy(account: "alice", proxy: "proxy1"),
            json: "{\"account\":\"alice\",\"proxy\":\"proxy1\"}",
            binary: Data("05616c6963650670726f787931"),
            opIdName: "account_validator_proxy"
        )
        roundTrip(fx)
    }
```

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.OperationTest/testRoundTrip_accountValidatorProxy`
Expected: BUILD FAILED — `Operation.AccountValidatorProxy` is undefined.

- [ ] **Step 3: Rename the struct**

Replace in `Sources/VIZ/Operation.swift` around lines 259–268:

```swift
    /// Sets a validator voting proxy.
    public struct AccountValidatorProxy: OperationType, Equatable {
        public var account: String
        public var proxy: String

        public init(account: String, proxy: String) {
            self.account = account
            self.proxy = proxy
        }
    }
```

- [ ] **Step 4: Update dispatch sites**

In `AnyOperation.init(from:)` around line 1126:

```swift
        case .account_validator_proxy: op = try container.decode(Operation.AccountValidatorProxy.self)
```

In `AnyOperation.encode(to:)` around line 1213:

```swift
        case let op as Operation.AccountValidatorProxy:
            try container.encode(OperationId.account_validator_proxy)
            try container.encode(op)
```

- [ ] **Step 5: Add deprecated typealias**

Append to the deprecated-aliases extension block:

```swift
    @available(*, deprecated, renamed: "AccountValidatorProxy")
    public typealias AccountWitnessProxy = AccountValidatorProxy
```

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename AccountWitnessProxy to AccountValidatorProxy"
```

---

## Task 5: Rename `Operation.ShutdownWitness` → `Operation.ShutdownValidator`

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (struct at line 911; dispatch at line 1140; deprecated-aliases block)
- Test: `Tests/UnitTests/Operation.swift` (rename `testVirtualDecode_shutdownWitness` at line 504)

**Context:** Virtual op (decode-only). No inner field rename. Single Swift property `owner` stays.

- [ ] **Step 1: Update the existing test**

In `Tests/UnitTests/Operation.swift`, find the test at line 504. Replace it:

```swift
    func testVirtualDecode_shutdownValidator() {
        assertVirtualDecodes(
            opIdName: "shutdown_validator",
            json: "{\"owner\":\"alice\"}",
            Operation.ShutdownValidator(owner: "alice")
        )
    }
```

Also add a legacy-name decode test right below it (asserts old `"shutdown_witness"` string still decodes to the new Swift type):

```swift
    func testVirtualDecode_shutdownValidator_legacyName() {
        assertVirtualDecodes(
            opIdName: "shutdown_witness",
            json: "{\"owner\":\"alice\"}",
            Operation.ShutdownValidator(owner: "alice")
        )
    }
```

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.OperationTest/testVirtualDecode_shutdownValidator`
Expected: BUILD FAILED — `Operation.ShutdownValidator` is undefined.

- [ ] **Step 3: Rename the struct**

Replace in `Sources/VIZ/Operation.swift` around line 911:

```swift
    public struct ShutdownValidator: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let owner: String
    }
```

- [ ] **Step 4: Update dispatch site**

In `AnyOperation.init(from:)` around line 1140:

```swift
        case .shutdown_validator: op = try container.decode(Operation.ShutdownValidator.self)
```

- [ ] **Step 5: Add deprecated typealias**

Append to the deprecated-aliases extension block:

```swift
    @available(*, deprecated, renamed: "ShutdownValidator")
    public typealias ShutdownWitness = ShutdownValidator
```

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename ShutdownWitness to ShutdownValidator"
```

---

## Task 6: Rename `Operation.WitnessReward` → `Operation.ValidatorReward`; rename inner `witness` field → `validator`; add dual-key decode

**Files:**
- Modify: `Sources/VIZ/Operation.swift` (struct at line 962; dispatch at line 1143; deprecated-aliases block)
- Test: `Tests/UnitTests/Operation.swift` (rename `testVirtualDecode_witnessReward` at line 549; add legacy-key test)

**Context:** Virtual op with renamed inner field. Properties are `let`, so no setter is needed on the deprecated `witness` alias.

- [ ] **Step 1: Update existing test + add legacy-key test**

In `Tests/UnitTests/Operation.swift`, replace the test around lines 549–554 and add a legacy-key test below:

```swift
    func testVirtualDecode_validatorReward() {
        assertVirtualDecodes(
            opIdName: "validator_reward",
            json: "{\"validator\":\"alice\",\"shares\":\"0.500000 VESTS\"}",
            Operation.ValidatorReward(validator: "alice", shares: Asset(0.5, .vests))
        )
    }

    func testVirtualDecode_validatorReward_legacyKeys() {
        // Both legacy op name AND legacy body field name simultaneously.
        assertVirtualDecodes(
            opIdName: "witness_reward",
            json: "{\"witness\":\"alice\",\"shares\":\"0.500000 VESTS\"}",
            Operation.ValidatorReward(validator: "alice", shares: Asset(0.5, .vests))
        )
    }
```

Note: this changes the struct's memberwise init from positional `(witness:, shares:)` to `(validator:, shares:)`. Since the existing struct uses memberwise-only synthesis (`let` properties, no explicit init), we provide an explicit init in Step 3 to set the canonical label.

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.OperationTest/testVirtualDecode_validatorReward`
Expected: BUILD FAILED — `Operation.ValidatorReward` is undefined.

- [ ] **Step 3: Rename the struct, add explicit canonical init, add dual-key decode**

Replace in `Sources/VIZ/Operation.swift` around lines 962–966:

```swift
    public struct ValidatorReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let validator: String
        public let shares: Asset

        public init(validator: String, shares: Asset) {
            self.validator = validator
            self.shares = shares
        }

        enum CodingKeys: String, CodingKey {
            case validator, shares
            case legacyWitness = "witness"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.shares = try c.decode(Asset.self, forKey: .shares)
            self.validator = (try? c.decode(String.self, forKey: .validator))
                          ?? (try c.decode(String.self, forKey: .legacyWitness))
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(validator, forKey: .validator)
            try c.encode(shares,    forKey: .shares)
        }
    }
```

- [ ] **Step 4: Update dispatch site**

In `AnyOperation.init(from:)` around line 1143:

```swift
        case .validator_reward: op = try container.decode(Operation.ValidatorReward.self)
```

- [ ] **Step 5: Add deprecated typealias + deprecated property alias + deprecated init**

Append to the deprecated-aliases extension block:

```swift
    @available(*, deprecated, renamed: "ValidatorReward")
    public typealias WitnessReward = ValidatorReward
```

Inside the `ValidatorReward` struct, after the canonical init, add:

```swift
        @available(*, deprecated, message: "Use init(validator:shares:)")
        public init(witness: String, shares: Asset) {
            self.init(validator: witness, shares: shares)
        }

        @available(*, deprecated, renamed: "validator")
        public var witness: String { validator }
```

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/VIZ/Operation.swift Tests/UnitTests/Operation.swift
git commit -m "refactor: rename WitnessReward to ValidatorReward with dual-key decode"
```

---

## Task 7: Rename `witness` / `witnessSignature` on `BlockHeader`, `SignedBlockHeader`, `SignedBlock`; add dual-key decode

**Files:**
- Modify: `Sources/VIZ/Block.swift`
- Test: `Tests/UnitTests/Block.swift`

**Context:** The two header structs currently rely on `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`. With manual `CodingKeys`, raw values must be in **camelCase** form (which is what the strategy converts JSON snake_case keys to). So `case legacyWitness = "witness"` works (JSON `"witness"` → converted to `"witness"` → matches), and `case legacyWitnessSignature = "witnessSignature"` works (JSON `"witness_signature"` → converted to `"witnessSignature"` → matches).

- [ ] **Step 1: Update the existing block test + add a sibling fixture with new keys + add a legacy-key decode test**

Replace the entirety of `Tests/UnitTests/Block.swift` with:

```swift
import Foundation
@testable import VIZ
import XCTest

class BlockTest: XCTestCase {
    func testCodable() throws {
        let block = try TestDecode(SignedBlock.self, json: block2000000_legacy)
        XCTAssertEqual(block.num, 2_000_000)
        XCTAssertEqual(block.validator, "steempty")
        XCTAssertEqual(block.validatorSignature, Signature("1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b"))
        XCTAssertEqual(block.timestamp, Date(timeIntervalSince1970: 1_464_911_925))
        XCTAssertEqual(block.transactions.count, 3)
        let op = block.transactions.first?.operations.first as? VIZ.Operation.Vote
        XCTAssertEqual(op?.voter, "proctologic")
        AssertEncodes(block, [
            "previous": "001e847f77b2d0bc1c29caf02b1a98d79aefb7ad",
            "timestamp": "2016-06-02T23:58:45",
            "validator": "steempty",
            "transaction_merkle_root": "3335e6efe04f09aac61ad1fcc241ada1e1e8fc62",
            "validator_signature": "1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b",
        ])
    }

    func testDecode_signedBlock_acceptsNewValidatorKeys() throws {
        // Sibling fixture using the new JSON keys (validator / validator_signature).
        let block = try TestDecode(SignedBlock.self, json: block2000000_new)
        XCTAssertEqual(block.validator, "steempty")
        XCTAssertEqual(block.validatorSignature, Signature("1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b"))
    }
}

// Legacy JSON: uses "witness" / "witness_signature".
fileprivate let block2000000_legacy = """
{
  "previous": "001e847f77b2d0bc1c29caf02b1a98d79aefb7ad",
  "timestamp": "2016-06-02T23:58:45",
  "witness": "steempty",
  "transaction_merkle_root": "3335e6efe04f09aac61ad1fcc241ada1e1e8fc62",
  "extensions": [],
  "witness_signature": "1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b",
  "transactions": [
    {
      "ref_block_num": 33918,
      "ref_block_prefix": 2329120500,
      "expiration": "2016-06-02T23:58:54",
      "operations": [
        [
          "vote",
          {
            "voter": "proctologic",
            "author": "pal",
            "permlink": "re-dantheman-re-pal-httpssteemit-comsteempalsniper-whale-vote-bot-strategy-20160602t162811551z",
            "weight": 10000
          }
        ]
      ],
      "extensions": [],
      "signatures": [
        "1f0ad8680045212314210892e338f14bc4fd34b2573e6217591b036be6222c5d980dbc2d3547429924389330e876ab650a1dd9548284d8a855c96b58c542d0a499"
      ],
      "transaction_id": "747e19a0a1511d162dfcb5258f62de520294982b",
      "block_num": 2000000,
      "transaction_num": 0
    },
    {
      "ref_block_num": 33919,
      "ref_block_prefix": 3167793783,
      "expiration": "2016-06-02T23:58:57",
      "operations": [
        [
          "vote",
          {
            "voter": "proctologic",
            "author": "oholiab",
            "permlink": "re-dantheman-re-streemian-re-re-dantheman-lessons-learned-from-curation-rewards-discussion-20160602t150813-20160602t161538485z",
            "weight": 10000
          }
        ]
      ],
      "extensions": [],
      "signatures": [
        "1f45456b18a8df371cb1890f15f4e9a7b59b9759d9982d3e96429343c2899fcda668a295bfd6eaa630785ed807aa93485301723870d6f34769bc25a6fbc91d0253"
      ],
      "transaction_id": "7ed4ca6109927b1593e33525db606e9cf867e4f4",
      "block_num": 2000000,
      "transaction_num": 1
    },
    {
      "ref_block_num": 33919,
      "ref_block_prefix": 3167793783,
      "expiration": "2016-06-02T23:58:57",
      "operations": [
        [
          "vote",
          {
            "voter": "proctologic",
            "author": "abit",
            "permlink": "re-dantheman-lessons-learned-from-curation-rewards-discussion-20160602t160856942z",
            "weight": 10000
          }
        ]
      ],
      "extensions": [],
      "signatures": [
        "1f5fd52ca5c91b118c8ac2f2f6f6df28bc10122baaabbd3f510c37b3201c86a4845419a0d6a17cf267c73d939f1fa7230c7f9f85e60b784e54cf041091d0cbb41f"
      ],
      "transaction_id": "ac7489dbe69ac338cae85824dc58160515095341",
      "block_num": 2000000,
      "transaction_num": 2
    }
  ],
  "block_id": "001e84802fe2d042906f33a9cc4fd49f024c7eb9",
  "signing_key": "STM7UiohU9S9Rg9ukx5cvRBgwcmYXjikDa4XM4Sy1V9jrBB7JzLmi",
  "transaction_ids": [
    "747e19a0a1511d162dfcb5258f62de520294982b",
    "7ed4ca6109927b1593e33525db606e9cf867e4f4",
    "ac7489dbe69ac338cae85824dc58160515095341"
  ]
}
"""

// New JSON: minimal fixture with "validator" / "validator_signature" and no transactions.
fileprivate let block2000000_new = """
{
  "previous": "001e847f77b2d0bc1c29caf02b1a98d79aefb7ad",
  "timestamp": "2016-06-02T23:58:45",
  "validator": "steempty",
  "transaction_merkle_root": "3335e6efe04f09aac61ad1fcc241ada1e1e8fc62",
  "extensions": [],
  "validator_signature": "1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b",
  "transactions": []
}
"""
```

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.BlockTest`
Expected: BUILD FAILED — `SignedBlock` has no `validator` or `validatorSignature` property.

- [ ] **Step 3: Update `_BlockHeader` protocol and the three header types in `Sources/VIZ/Block.swift`**

Replace the contents from line 41 through line 114 (the `_BlockHeader` protocol, `BlockHeader`, `SignedBlockHeader`, `SignedBlock`):

```swift
/// Internal protocol for a block header.
fileprivate protocol _BlockHeader: Codable {
    /// The block id of the block preceding this one.
    var previous: BlockId { get }
    /// Time when block was generated.
    var timestamp: Date { get }
    /// Validator who produced it.
    var validator: String { get }
    /// Merkle root hash, ripemd160.
    var transactionMerkleRoot: Data { get }
    /// Block extensions.
    var extensions: [BlockExtension] { get }
}

/// A type representing a VIZ block header.
public struct BlockHeader: _BlockHeader {
    public let previous: BlockId
    public let timestamp: Date
    public let validator: String
    public let transactionMerkleRoot: Data
    public let extensions: [BlockExtension]

    enum CodingKeys: String, CodingKey {
        case previous, timestamp, validator, transactionMerkleRoot, extensions
        case legacyWitness = "witness"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.previous = try c.decode(BlockId.self, forKey: .previous)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.transactionMerkleRoot = try c.decode(Data.self, forKey: .transactionMerkleRoot)
        self.extensions = try c.decode([BlockExtension].self, forKey: .extensions)
        self.validator = (try? c.decode(String.self, forKey: .validator))
                      ?? (try c.decode(String.self, forKey: .legacyWitness))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(previous, forKey: .previous)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(validator, forKey: .validator)
        try c.encode(transactionMerkleRoot, forKey: .transactionMerkleRoot)
        try c.encode(extensions, forKey: .extensions)
    }
}

/// A type representing a signed VIZ block header.
public struct SignedBlockHeader: _BlockHeader, Equatable, Sendable {
    public let previous: BlockId
    public let timestamp: Date
    public let validator: String
    public let transactionMerkleRoot: Data
    public let extensions: [BlockExtension]
    public let validatorSignature: Signature

    enum CodingKeys: String, CodingKey {
        case previous, timestamp, validator, transactionMerkleRoot, extensions, validatorSignature
        case legacyWitness = "witness"
        case legacyWitnessSignature = "witnessSignature"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.previous = try c.decode(BlockId.self, forKey: .previous)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.transactionMerkleRoot = try c.decode(Data.self, forKey: .transactionMerkleRoot)
        self.extensions = try c.decode([BlockExtension].self, forKey: .extensions)
        self.validator = (try? c.decode(String.self, forKey: .validator))
                      ?? (try c.decode(String.self, forKey: .legacyWitness))
        self.validatorSignature = (try? c.decode(Signature.self, forKey: .validatorSignature))
                               ?? (try c.decode(Signature.self, forKey: .legacyWitnessSignature))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(previous, forKey: .previous)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(validator, forKey: .validator)
        try c.encode(transactionMerkleRoot, forKey: .transactionMerkleRoot)
        try c.encode(extensions, forKey: .extensions)
        try c.encode(validatorSignature, forKey: .validatorSignature)
    }
}

/// A type representing a VIZ block.
public struct SignedBlock: _BlockHeader, Equatable, Sendable {
    /// The transactions included in this block.
    public let transactions: [Transaction]
    /// The block number.
    public var num: UInt32 {
        return self.header.previous.num + 1
    }

    private let header: SignedBlockHeader

    /// Create a new Signed block.
    public init(header: SignedBlockHeader, transactions: [Transaction]) {
        self.header = header
        self.transactions = transactions
    }

    // Header proxy.
    public var previous: BlockId { return self.header.previous }
    public var timestamp: Date { return self.header.timestamp }
    public var validator: String { return self.header.validator }
    public var transactionMerkleRoot: Data { return self.header.transactionMerkleRoot }
    public var extensions: [BlockExtension] { return self.header.extensions }
    public var validatorSignature: Signature { return self.header.validatorSignature }

    private enum Key: CodingKey {
        case transactions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.transactions = try container.decode([Transaction].self, forKey: .transactions)
        self.header = try SignedBlockHeader(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try self.header.encode(to: encoder)
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(self.transactions, forKey: .transactions)
    }
}
```

- [ ] **Step 4: Add deprecated computed-property aliases at the bottom of `Sources/VIZ/Block.swift`**

Append at the very end of the file (after the `extension BlockExtension: Codable { ... }`):

```swift
// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension BlockHeader {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }
}

extension SignedBlockHeader {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }

    @available(*, deprecated, renamed: "validatorSignature")
    public var witnessSignature: Signature { validatorSignature }
}

extension SignedBlock {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }

    @available(*, deprecated, renamed: "validatorSignature")
    public var witnessSignature: Signature { validatorSignature }
}
```

- [ ] **Step 5: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — including the renamed `testCodable` (now decoding the legacy-key fixture into the new properties) and the new `testDecode_signedBlock_acceptsNewValidatorKeys`.

- [ ] **Step 6: Commit**

```bash
git add Sources/VIZ/Block.swift Tests/UnitTests/Block.swift
git commit -m "refactor: rename Block.witness/witnessSignature to validator/validatorSignature with dual-key decode"
```

---

## Task 8: Rename `DynamicGlobalProperties.currentWitness` / `.inflationWitnessPercent`; add dual-key decode

**Files:**
- Modify: `Sources/VIZ/API.swift` (struct at lines 13–38)
- Test: `Tests/UnitTests/API.swift` (extend existing test or add new tests)

**Context:** Uses `convertFromSnakeCase` decoder strategy. CodingKey raw values must be **camelCase** form. There is no existing decode test for `DynamicGlobalProperties` in `Tests/UnitTests/API.swift` (the file's existing test covers `ExtendedAccount`). We add the test file's first `DynamicGlobalProperties` tests.

- [ ] **Step 1: Add failing dual-decode tests**

Open `Tests/UnitTests/API.swift`. At the end of the existing `APITest` class (before the closing brace), add:

```swift
    func testDynamicGlobalProperties_decodesNewKeys() throws {
        let json = """
        {
          "head_block_number": 1,
          "head_block_id": "00000001aabbccddeeff",
          "time": "2026-05-19T12:00:00",
          "genesis_time": "2018-09-29T13:00:00",
          "current_validator": "alice",
          "committee_fund": "0.000 VIZ",
          "committee_requests": 0,
          "current_supply": "0.000 VIZ",
          "total_vesting_fund": "0.000 VIZ",
          "total_vesting_shares": "0.000000 VESTS",
          "total_reward_fund": "0.000 VIZ",
          "total_reward_shares": "0",
          "inflation_calc_block_num": 0,
          "inflation_validator_percent": 1500,
          "inflation_ratio": 0,
          "average_block_size": 0,
          "maximum_block_size": 0,
          "current_aslot": 0,
          "recent_slots_filled": "0",
          "participation_count": 0,
          "last_irreversible_block_num": 0,
          "max_virtual_bandwidth": "0",
          "current_reserve_ratio": 0,
          "vote_regeneration_per_day": 0
        }
        """
        let dgp = try TestDecode(API.DynamicGlobalProperties.self, json: json)
        XCTAssertEqual(dgp.currentValidator, "alice")
        XCTAssertEqual(dgp.inflationValidatorPercent, 1500)
    }

    func testDynamicGlobalProperties_decodesLegacyKeys() throws {
        let json = """
        {
          "head_block_number": 1,
          "head_block_id": "00000001aabbccddeeff",
          "time": "2026-05-19T12:00:00",
          "genesis_time": "2018-09-29T13:00:00",
          "current_witness": "alice",
          "committee_fund": "0.000 VIZ",
          "committee_requests": 0,
          "current_supply": "0.000 VIZ",
          "total_vesting_fund": "0.000 VIZ",
          "total_vesting_shares": "0.000000 VESTS",
          "total_reward_fund": "0.000 VIZ",
          "total_reward_shares": "0",
          "inflation_calc_block_num": 0,
          "inflation_witness_percent": 1500,
          "inflation_ratio": 0,
          "average_block_size": 0,
          "maximum_block_size": 0,
          "current_aslot": 0,
          "recent_slots_filled": "0",
          "participation_count": 0,
          "last_irreversible_block_num": 0,
          "max_virtual_bandwidth": "0",
          "current_reserve_ratio": 0,
          "vote_regeneration_per_day": 0
        }
        """
        let dgp = try TestDecode(API.DynamicGlobalProperties.self, json: json)
        XCTAssertEqual(dgp.currentValidator, "alice")
        XCTAssertEqual(dgp.inflationValidatorPercent, 1500)
    }
```

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.APITest/testDynamicGlobalProperties_decodesNewKeys`
Expected: BUILD FAILED — `dgp.currentValidator` and `dgp.inflationValidatorPercent` are undefined.

- [ ] **Step 3: Rename the two fields and add manual `init(from:)` with `CodingKeys`**

Replace the `DynamicGlobalProperties` struct in `Sources/VIZ/API.swift` (lines 13–38):

```swift
    public struct DynamicGlobalProperties: Decodable, Sendable {
        public let headBlockNumber: UInt32
        public let headBlockId: BlockId
        public let time: Date
        public let genesisTime: Date
        public let currentValidator: String
        public let committeeFund: Asset
        public let committeeRequests: UInt32
        public let currentSupply: Asset
        public let totalVestingFund: Asset
        public let totalVestingShares: Asset
        public let totalRewardFund: Asset
        public let totalRewardShares: String
        public let inflationCalcBlockNum: UInt32
        public let inflationValidatorPercent: Int16
        public let inflationRatio: Int16
        public let averageBlockSize: UInt32
        public let maximumBlockSize: UInt32
        public let currentAslot: UInt32
        public let recentSlotsFilled: String
        public let participationCount: UInt32
        public let lastIrreversibleBlockNum: UInt32
        public let maxVirtualBandwidth: String
        public let currentReserveRatio: UInt64
        public let voteRegenerationPerDay: UInt32

        // CodingKey raw values must be camelCase because the decoder applies
        // .convertFromSnakeCase before matching.
        enum CodingKeys: String, CodingKey {
            case headBlockNumber, headBlockId, time, genesisTime,
                 currentValidator,
                 committeeFund, committeeRequests, currentSupply,
                 totalVestingFund, totalVestingShares, totalRewardFund, totalRewardShares,
                 inflationCalcBlockNum,
                 inflationValidatorPercent,
                 inflationRatio, averageBlockSize, maximumBlockSize, currentAslot,
                 recentSlotsFilled, participationCount, lastIrreversibleBlockNum,
                 maxVirtualBandwidth, currentReserveRatio, voteRegenerationPerDay
            case legacyCurrentWitness        = "currentWitness"
            case legacyInflationWitnessPercent = "inflationWitnessPercent"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.headBlockNumber = try c.decode(UInt32.self, forKey: .headBlockNumber)
            self.headBlockId = try c.decode(BlockId.self, forKey: .headBlockId)
            self.time = try c.decode(Date.self, forKey: .time)
            self.genesisTime = try c.decode(Date.self, forKey: .genesisTime)
            self.committeeFund = try c.decode(Asset.self, forKey: .committeeFund)
            self.committeeRequests = try c.decode(UInt32.self, forKey: .committeeRequests)
            self.currentSupply = try c.decode(Asset.self, forKey: .currentSupply)
            self.totalVestingFund = try c.decode(Asset.self, forKey: .totalVestingFund)
            self.totalVestingShares = try c.decode(Asset.self, forKey: .totalVestingShares)
            self.totalRewardFund = try c.decode(Asset.self, forKey: .totalRewardFund)
            self.totalRewardShares = try c.decode(String.self, forKey: .totalRewardShares)
            self.inflationCalcBlockNum = try c.decode(UInt32.self, forKey: .inflationCalcBlockNum)
            self.inflationRatio = try c.decode(Int16.self, forKey: .inflationRatio)
            self.averageBlockSize = try c.decode(UInt32.self, forKey: .averageBlockSize)
            self.maximumBlockSize = try c.decode(UInt32.self, forKey: .maximumBlockSize)
            self.currentAslot = try c.decode(UInt32.self, forKey: .currentAslot)
            self.recentSlotsFilled = try c.decode(String.self, forKey: .recentSlotsFilled)
            self.participationCount = try c.decode(UInt32.self, forKey: .participationCount)
            self.lastIrreversibleBlockNum = try c.decode(UInt32.self, forKey: .lastIrreversibleBlockNum)
            self.maxVirtualBandwidth = try c.decode(String.self, forKey: .maxVirtualBandwidth)
            self.currentReserveRatio = try c.decode(UInt64.self, forKey: .currentReserveRatio)
            self.voteRegenerationPerDay = try c.decode(UInt32.self, forKey: .voteRegenerationPerDay)
            self.currentValidator = (try? c.decode(String.self, forKey: .currentValidator))
                                 ?? (try c.decode(String.self, forKey: .legacyCurrentWitness))
            self.inflationValidatorPercent = (try? c.decode(Int16.self, forKey: .inflationValidatorPercent))
                                          ?? (try c.decode(Int16.self, forKey: .legacyInflationWitnessPercent))
        }
    }
```

- [ ] **Step 4: Add deprecated computed-property aliases**

At the very bottom of `Sources/VIZ/API.swift` (after the existing `public struct API { ... }` block — these go at file scope, not inside API), add:

```swift
// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension API.DynamicGlobalProperties {
    @available(*, deprecated, renamed: "currentValidator")
    public var currentWitness: String { currentValidator }

    @available(*, deprecated, renamed: "inflationValidatorPercent")
    public var inflationWitnessPercent: Int16 { inflationValidatorPercent }
}
```

- [ ] **Step 5: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — both new tests and all existing tests.

- [ ] **Step 6: Commit**

```bash
git add Sources/VIZ/API.swift Tests/UnitTests/API.swift
git commit -m "refactor: rename DynamicGlobalProperties witness fields to validator with dual-key decode"
```

---

## Task 9: Rename `ExtendedAccount.witnessesVotedFor` / `.witnessesVoteWeight` / `.witnessVotes`; add dual-key decode

**Files:**
- Modify: `Sources/VIZ/API.swift` (struct at lines 91–156)
- Test: `Tests/UnitTests/API.swift` (existing test at line 55 references the witness-named init labels; add a legacy-key decode test)

**Context:** `ExtendedAccount` has auto-synthesized `Decodable` with no custom init — so callers in tests pass values via the memberwise init (`witnessesVotedFor:`, etc.). We need to (a) rename properties, (b) provide an explicit memberwise init under the new labels (auto-synth memberwise is internal, so callers won't get it for public structs — but since this struct currently *is* called from a test, that means the memberwise init *is* exposed as `public` somehow — verify in Step 1).

Actually `ExtendedAccount` uses auto-synth with no explicit init. In Swift, auto-synth memberwise init is `internal` by default, even for public structs — but the test code uses `@testable import VIZ`, which exposes internal symbols. So the test's call `API.ExtendedAccount(id:, name:, ...)` works because of `@testable`. After our rename, the auto-synth memberwise init still works (it'll just use the new labels), but the test code calls the old labels and breaks.

- [ ] **Step 1: Update the existing `APITest.testEnergy` (or equivalent) and add a legacy-key decode test**

Inspect `Tests/UnitTests/API.swift` first. The relevant call (around line 55) constructs an `API.ExtendedAccount` with positional/labeled arguments including `witnessesVotedFor: 0`, `witnessesVoteWeight: API.Share(0)`, `witnessVotes: []`. Update those labels:

```swift
            validatorsVotedFor: 0,
            validatorsVoteWeight: API.Share(0),
            // ... other fields unchanged ...
            validatorVotes: [],
```

Then add a new legacy-key decode test at the bottom of the test class (replace `<fixture-fields-as-needed>` based on what's required to round-trip an ExtendedAccount — match the field list from the struct):

```swift
    func testExtendedAccount_decodesLegacyWitnessKeys() throws {
        // Construct a JSON object with the LEGACY witness field names and assert that decoding
        // populates the new validator-named properties.
        let json = """
        {
          "id": 0,
          "name": "alice",
          "master_authority": {"weight_threshold":1,"account_auths":[],"key_auths":[]},
          "active_authority": {"weight_threshold":1,"account_auths":[],"key_auths":[]},
          "regular_authority": {"weight_threshold":1,"account_auths":[],"key_auths":[]},
          "memo_key": "VIZ1111111111111111111111111111111114T1Anm",
          "json_metadata": "",
          "proxy": "",
          "referrer": "",
          "last_master_update": "1970-01-01T00:00:00",
          "last_account_update": "1970-01-01T00:00:00",
          "created": "1970-01-01T00:00:00",
          "recovery_account": "",
          "last_account_recovery": "1970-01-01T00:00:00",
          "awarded_rshares": 0,
          "custom_sequence": 0,
          "custom_sequence_block_num": 0,
          "energy": 0,
          "last_vote_time": "1970-01-01T00:00:00",
          "balance": "0.000 VIZ",
          "receiver_awards": 0,
          "benefactor_awards": 0,
          "vesting_shares": "0.000000 VESTS",
          "delegated_vesting_shares": "0.000000 VESTS",
          "received_vesting_shares": "0.000000 VESTS",
          "vesting_withdraw_rate": "0.000000 VESTS",
          "next_vesting_withdrawal": "1970-01-01T00:00:00",
          "withdrawn": 0,
          "to_withdraw": 0,
          "withdraw_routes": 0,
          "proxied_vsf_votes": [],
          "witnesses_voted_for": 7,
          "witnesses_vote_weight": 99,
          "last_post": "1970-01-01T00:00:00",
          "last_root_post": "1970-01-01T00:00:00",
          "average_bandwidth": 0,
          "lifetime_bandwidth": 0,
          "last_bandwidth_update": "1970-01-01T00:00:00",
          "witness_votes": ["alice", "bob"],
          "valid": true,
          "account_seller": "",
          "account_offer_price": "0.000 VIZ",
          "account_on_sale": false,
          "subaccount_seller": "",
          "subaccount_offer_price": "0.000 VIZ",
          "subaccount_on_sale": false
        }
        """
        let acc = try TestDecode(API.ExtendedAccount.self, json: json)
        XCTAssertEqual(acc.validatorsVotedFor, 7)
        XCTAssertEqual(acc.validatorsVoteWeight.value, 99)
        XCTAssertEqual(acc.validatorVotes, ["alice", "bob"])
    }
```

- [ ] **Step 2: Run and verify build failure**

Run: `swift test --filter UnitTests.APITest/testExtendedAccount_decodesLegacyWitnessKeys`
Expected: BUILD FAILED — `validatorsVotedFor`, `validatorsVoteWeight`, `validatorVotes` are undefined.

- [ ] **Step 3: Rename the 3 fields and add a manual `init(from:)` with CodingKeys for legacy fallback**

Replace the `ExtendedAccount` struct definition in `Sources/VIZ/API.swift` (lines 91–156). Keep all non-renamed fields exactly as they are. The three renames: `witnessesVotedFor` → `validatorsVotedFor`, `witnessesVoteWeight` → `validatorsVoteWeight`, `witnessVotes` → `validatorVotes`. Add a full `CodingKeys` enum and manual `init(from:)`:

```swift
    /// The "extended" account object returned by get_accounts.
    public struct ExtendedAccount: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let masterAuthority: Authority
        public let activeAuthority: Authority
        public let regularAuthority: Authority
        public let memoKey: PublicKey
        public let jsonMetadata: String
        public let proxy: String
        public let referrer: String
        public let lastMasterUpdate: Date
        public let lastAccountUpdate: Date
        public let created: Date
        public let recoveryAccount: String
        public let lastAccountRecovery: Date
        public let awardedRshares: UInt64
        public let customSequence: UInt64
        public let customSequenceBlockNum: UInt64
        public let energy: Int32
        public let lastVoteTime: Date
        public let balance: Asset
        public let receiverAwards: UInt64
        public let benefactorAwards: UInt64
        public let vestingShares: Asset
        public let delegatedVestingShares: Asset
        public let receivedVestingShares: Asset
        public let vestingWithdrawRate: Asset
        public let nextVestingWithdrawal: Date
        public let withdrawn: Share
        public let toWithdraw: Share
        public let withdrawRoutes: UInt16
        public let proxiedVsfVotes: [Share]
        public let validatorsVotedFor: UInt16
        public let validatorsVoteWeight: Share
        public let lastPost: Date
        public let lastRootPost: Date
        public let averageBandwidth: Share
        public let lifetimeBandwidth: Share
        public let lastBandwidthUpdate: Date
        public let validatorVotes: [String]
        public let valid: Bool
        public let accountSeller: String
        public let accountOfferPrice: Asset
        public let accountOnSale: Bool
        public let subaccountSeller: String
        public let subaccountOfferPrice: Asset
        public let subaccountOnSale: Bool

        public var effectiveVestingShares: Double {
            vestingShares.resolvedAmount
            + receivedVestingShares.resolvedAmount
            - delegatedVestingShares.resolvedAmount
        }

        // TODO: take a Date parameter for testability instead of reading Date() implicitly
        public var currentEnergy: Int {
            let deltaTime = Date().timeIntervalSince(lastVoteTime)
            var e = Float64(energy) + (deltaTime * 10000 / CHAIN_ENERGY_REGENERATION_SECONDS)
            if e > 10000 {
                e = 10000
            } else if e < 0 {
                e = 0
            }
            return Int(e)
        }

        // Explicit memberwise init so the test can construct one with the new labels.
        public init(
            id: Int, name: String,
            masterAuthority: Authority, activeAuthority: Authority, regularAuthority: Authority,
            memoKey: PublicKey, jsonMetadata: String,
            proxy: String, referrer: String,
            lastMasterUpdate: Date, lastAccountUpdate: Date, created: Date,
            recoveryAccount: String, lastAccountRecovery: Date,
            awardedRshares: UInt64, customSequence: UInt64, customSequenceBlockNum: UInt64,
            energy: Int32, lastVoteTime: Date,
            balance: Asset, receiverAwards: UInt64, benefactorAwards: UInt64,
            vestingShares: Asset, delegatedVestingShares: Asset, receivedVestingShares: Asset,
            vestingWithdrawRate: Asset, nextVestingWithdrawal: Date,
            withdrawn: Share, toWithdraw: Share, withdrawRoutes: UInt16,
            proxiedVsfVotes: [Share],
            validatorsVotedFor: UInt16, validatorsVoteWeight: Share,
            lastPost: Date, lastRootPost: Date,
            averageBandwidth: Share, lifetimeBandwidth: Share, lastBandwidthUpdate: Date,
            validatorVotes: [String], valid: Bool,
            accountSeller: String, accountOfferPrice: Asset, accountOnSale: Bool,
            subaccountSeller: String, subaccountOfferPrice: Asset, subaccountOnSale: Bool
        ) {
            self.id = id; self.name = name
            self.masterAuthority = masterAuthority; self.activeAuthority = activeAuthority; self.regularAuthority = regularAuthority
            self.memoKey = memoKey; self.jsonMetadata = jsonMetadata
            self.proxy = proxy; self.referrer = referrer
            self.lastMasterUpdate = lastMasterUpdate; self.lastAccountUpdate = lastAccountUpdate; self.created = created
            self.recoveryAccount = recoveryAccount; self.lastAccountRecovery = lastAccountRecovery
            self.awardedRshares = awardedRshares; self.customSequence = customSequence; self.customSequenceBlockNum = customSequenceBlockNum
            self.energy = energy; self.lastVoteTime = lastVoteTime
            self.balance = balance; self.receiverAwards = receiverAwards; self.benefactorAwards = benefactorAwards
            self.vestingShares = vestingShares; self.delegatedVestingShares = delegatedVestingShares; self.receivedVestingShares = receivedVestingShares
            self.vestingWithdrawRate = vestingWithdrawRate; self.nextVestingWithdrawal = nextVestingWithdrawal
            self.withdrawn = withdrawn; self.toWithdraw = toWithdraw; self.withdrawRoutes = withdrawRoutes
            self.proxiedVsfVotes = proxiedVsfVotes
            self.validatorsVotedFor = validatorsVotedFor; self.validatorsVoteWeight = validatorsVoteWeight
            self.lastPost = lastPost; self.lastRootPost = lastRootPost
            self.averageBandwidth = averageBandwidth; self.lifetimeBandwidth = lifetimeBandwidth; self.lastBandwidthUpdate = lastBandwidthUpdate
            self.validatorVotes = validatorVotes; self.valid = valid
            self.accountSeller = accountSeller; self.accountOfferPrice = accountOfferPrice; self.accountOnSale = accountOnSale
            self.subaccountSeller = subaccountSeller; self.subaccountOfferPrice = subaccountOfferPrice; self.subaccountOnSale = subaccountOnSale
        }

        // CodingKey raw values are camelCase because the decoder applies .convertFromSnakeCase
        // before matching. Legacy keys use the pre-rename camelCase form.
        enum CodingKeys: String, CodingKey {
            case id, name, masterAuthority, activeAuthority, regularAuthority,
                 memoKey, jsonMetadata, proxy, referrer,
                 lastMasterUpdate, lastAccountUpdate, created,
                 recoveryAccount, lastAccountRecovery,
                 awardedRshares, customSequence, customSequenceBlockNum,
                 energy, lastVoteTime, balance, receiverAwards, benefactorAwards,
                 vestingShares, delegatedVestingShares, receivedVestingShares,
                 vestingWithdrawRate, nextVestingWithdrawal,
                 withdrawn, toWithdraw, withdrawRoutes, proxiedVsfVotes,
                 validatorsVotedFor, validatorsVoteWeight,
                 lastPost, lastRootPost,
                 averageBandwidth, lifetimeBandwidth, lastBandwidthUpdate,
                 validatorVotes, valid,
                 accountSeller, accountOfferPrice, accountOnSale,
                 subaccountSeller, subaccountOfferPrice, subaccountOnSale
            case legacyWitnessesVotedFor   = "witnessesVotedFor"
            case legacyWitnessesVoteWeight = "witnessesVoteWeight"
            case legacyWitnessVotes        = "witnessVotes"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            self.masterAuthority = try c.decode(Authority.self, forKey: .masterAuthority)
            self.activeAuthority = try c.decode(Authority.self, forKey: .activeAuthority)
            self.regularAuthority = try c.decode(Authority.self, forKey: .regularAuthority)
            self.memoKey = try c.decode(PublicKey.self, forKey: .memoKey)
            self.jsonMetadata = try c.decode(String.self, forKey: .jsonMetadata)
            self.proxy = try c.decode(String.self, forKey: .proxy)
            self.referrer = try c.decode(String.self, forKey: .referrer)
            self.lastMasterUpdate = try c.decode(Date.self, forKey: .lastMasterUpdate)
            self.lastAccountUpdate = try c.decode(Date.self, forKey: .lastAccountUpdate)
            self.created = try c.decode(Date.self, forKey: .created)
            self.recoveryAccount = try c.decode(String.self, forKey: .recoveryAccount)
            self.lastAccountRecovery = try c.decode(Date.self, forKey: .lastAccountRecovery)
            self.awardedRshares = try c.decode(UInt64.self, forKey: .awardedRshares)
            self.customSequence = try c.decode(UInt64.self, forKey: .customSequence)
            self.customSequenceBlockNum = try c.decode(UInt64.self, forKey: .customSequenceBlockNum)
            self.energy = try c.decode(Int32.self, forKey: .energy)
            self.lastVoteTime = try c.decode(Date.self, forKey: .lastVoteTime)
            self.balance = try c.decode(Asset.self, forKey: .balance)
            self.receiverAwards = try c.decode(UInt64.self, forKey: .receiverAwards)
            self.benefactorAwards = try c.decode(UInt64.self, forKey: .benefactorAwards)
            self.vestingShares = try c.decode(Asset.self, forKey: .vestingShares)
            self.delegatedVestingShares = try c.decode(Asset.self, forKey: .delegatedVestingShares)
            self.receivedVestingShares = try c.decode(Asset.self, forKey: .receivedVestingShares)
            self.vestingWithdrawRate = try c.decode(Asset.self, forKey: .vestingWithdrawRate)
            self.nextVestingWithdrawal = try c.decode(Date.self, forKey: .nextVestingWithdrawal)
            self.withdrawn = try c.decode(Share.self, forKey: .withdrawn)
            self.toWithdraw = try c.decode(Share.self, forKey: .toWithdraw)
            self.withdrawRoutes = try c.decode(UInt16.self, forKey: .withdrawRoutes)
            self.proxiedVsfVotes = try c.decode([Share].self, forKey: .proxiedVsfVotes)
            self.lastPost = try c.decode(Date.self, forKey: .lastPost)
            self.lastRootPost = try c.decode(Date.self, forKey: .lastRootPost)
            self.averageBandwidth = try c.decode(Share.self, forKey: .averageBandwidth)
            self.lifetimeBandwidth = try c.decode(Share.self, forKey: .lifetimeBandwidth)
            self.lastBandwidthUpdate = try c.decode(Date.self, forKey: .lastBandwidthUpdate)
            self.valid = try c.decode(Bool.self, forKey: .valid)
            self.accountSeller = try c.decode(String.self, forKey: .accountSeller)
            self.accountOfferPrice = try c.decode(Asset.self, forKey: .accountOfferPrice)
            self.accountOnSale = try c.decode(Bool.self, forKey: .accountOnSale)
            self.subaccountSeller = try c.decode(String.self, forKey: .subaccountSeller)
            self.subaccountOfferPrice = try c.decode(Asset.self, forKey: .subaccountOfferPrice)
            self.subaccountOnSale = try c.decode(Bool.self, forKey: .subaccountOnSale)
            self.validatorsVotedFor = (try? c.decode(UInt16.self, forKey: .validatorsVotedFor))
                                   ?? (try c.decode(UInt16.self, forKey: .legacyWitnessesVotedFor))
            self.validatorsVoteWeight = (try? c.decode(Share.self, forKey: .validatorsVoteWeight))
                                     ?? (try c.decode(Share.self, forKey: .legacyWitnessesVoteWeight))
            self.validatorVotes = (try? c.decode([String].self, forKey: .validatorVotes))
                               ?? (try c.decode([String].self, forKey: .legacyWitnessVotes))
        }
    }
```

- [ ] **Step 4: Add deprecated computed-property aliases**

Append to the existing `// MARK: - Deprecated aliases` block at the bottom of `Sources/VIZ/API.swift` (created in Task 8):

```swift
extension API.ExtendedAccount {
    @available(*, deprecated, renamed: "validatorsVotedFor")
    public var witnessesVotedFor: UInt16 { validatorsVotedFor }

    @available(*, deprecated, renamed: "validatorsVoteWeight")
    public var witnessesVoteWeight: API.Share { validatorsVoteWeight }

    @available(*, deprecated, renamed: "validatorVotes")
    public var witnessVotes: [String] { validatorVotes }
}
```

- [ ] **Step 5: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — new legacy-key test plus the renamed `APITest` energy assertion now using the validator-named labels.

- [ ] **Step 6: Commit**

```bash
git add Sources/VIZ/API.swift Tests/UnitTests/API.swift
git commit -m "refactor: rename ExtendedAccount witness fields to validator with dual-key decode"
```

---

## Task 10: Update `Client.swift` namespace switch to accept both old and new method names

**Files:**
- Modify: `Sources/VIZ/Client.swift` (lines 46–47)
- Test: optional sanity test — not required since there is no existing test for the namespace switch.

**Context:** The current switch arm maps 8 `get_*witness*` method names to `witness_api`. After the migration, the namespace is `validator_api`. The node continues to accept old method names for one release cycle (with deprecation warnings server-side). We route **both** old and new method names to the new namespace so existing callers and any new typed Request structs (added in a future spec) both work.

- [ ] **Step 1: Update the switch arm**

In `Sources/VIZ/Client.swift`, replace lines 46–47:

```swift
        case "get_active_witnesses", "get_active_validators",
             "get_witness_by_account", "get_validator_by_account",
             "get_witness_count", "get_validator_count",
             "get_witness_schedule", "get_validator_schedule",
             "get_witnesses", "get_validators",
             "get_witnesses_by_counted_vote", "get_validators_by_counted_vote",
             "get_witnesses_by_vote", "get_validators_by_vote",
             "lookup_witness_accounts", "lookup_validator_accounts":
            return "validator_api"
```

- [ ] **Step 2: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — no test exercises this switch, but the build must remain clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/VIZ/Client.swift
git commit -m "refactor: route witness/validator API methods to validator_api namespace"
```

---

## Task 11: Add deprecated-alias compile-smoke test

**Files:**
- Create: `Tests/UnitTests/DeprecatedAliases.swift`

**Context:** This file references each deprecated typealias, deprecated property, and deprecated init exactly once to pin the compat surface. Decorate the function (and the wrapping class) with `@available(*, deprecated)` so the deprecation warnings inside the function body are silenced — the function itself is the canary, not the warnings.

- [ ] **Step 1: Create the test file**

Create `Tests/UnitTests/DeprecatedAliases.swift`:

```swift
@testable import VIZ
import XCTest

/// Compile-smoke test: every deprecated alias / property / init introduced by the
/// witness → validator migration is referenced exactly once. If any is removed
/// accidentally, this file fails to compile.
///
/// The class itself is marked deprecated so that warnings emitted by the deprecated
/// references inside it are silenced (Swift suppresses deprecation diagnostics
/// inside contexts that are themselves deprecated).
@available(*, deprecated, message: "Compile-smoke test for migration aliases.")
class DeprecatedAliasesTest: XCTestCase {
    func testCompiles() {
        // --- Operation typealiases ---
        let _: Operation.WitnessUpdate.Type            = Operation.WitnessUpdate.self
        let _: Operation.AccountWitnessVote.Type       = Operation.AccountWitnessVote.self
        let _: Operation.AccountWitnessProxy.Type      = Operation.AccountWitnessProxy.self
        let _: Operation.ShutdownWitness.Type          = Operation.ShutdownWitness.self
        let _: Operation.WitnessReward.Type            = Operation.WitnessReward.self

        // --- Operation deprecated init overloads ---
        let vote = Operation.AccountValidatorVote(account: "a", witness: "b", approve: true)
        XCTAssertEqual(vote.witness, "b")           // deprecated computed property
        XCTAssertEqual(vote.validator, "b")

        let reward = Operation.ValidatorReward(witness: "a", shares: Asset(0.5, .vests))
        XCTAssertEqual(reward.witness, "a")         // deprecated computed property
        XCTAssertEqual(reward.validator, "a")

        // --- Block deprecated property aliases ---
        // (Construction omitted — we only need the property accesses to compile.)
        func touchBlockAliases(_ h: BlockHeader, _ sh: SignedBlockHeader, _ b: SignedBlock) {
            _ = h.witness
            _ = sh.witness
            _ = sh.witnessSignature
            _ = b.witness
            _ = b.witnessSignature
        }
        _ = touchBlockAliases

        // --- API deprecated property aliases ---
        func touchAPIAliases(_ dgp: API.DynamicGlobalProperties, _ acc: API.ExtendedAccount) {
            _ = dgp.currentWitness
            _ = dgp.inflationWitnessPercent
            _ = acc.witnessesVotedFor
            _ = acc.witnessesVoteWeight
            _ = acc.witnessVotes
        }
        _ = touchAPIAliases
    }
}
```

- [ ] **Step 2: Run the new test**

Run: `swift test --filter UnitTests.DeprecatedAliasesTest`
Expected: PASS — the test compiles and runs successfully. Compilation success is the actual signal.

- [ ] **Step 3: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnitTests/DeprecatedAliases.swift
git commit -m "test: add compile-smoke test for witness→validator deprecated aliases"
```

---

## Task 12: Update `XCTestManifests.swift` for Linux

**Files:**
- Modify: `Tests/UnitTests/XCTestManifests.swift`

**Context:** Linux SwiftPM doesn't use Objective-C runtime introspection, so test discovery is manual. Every test method must be listed in the manifest. Renames from Tasks 2–9 changed test method names; Task 11 added a new test class; Tasks 3, 5, 6, 7, 8, 9 added new test methods.

- [ ] **Step 1: Update the `OperationTest.__allTests` array**

In `Tests/UnitTests/XCTestManifests.swift`, replace the 5 renamed entries and add the 3 new entries. The full updated `extension OperationTest` block:

```swift
extension OperationTest {
    static let __allTests = [
        ("testDecodable", testDecodable),
        ("testDecode_accountValidatorVote_legacyWitnessKey", testDecode_accountValidatorVote_legacyWitnessKey),
        ("testEncodable", testEncodable),
        ("testEncodeAsymmetry_definedButNotEncodable", testEncodeAsymmetry_definedButNotEncodable),
        ("testOperationId_acceptsLegacyAndNewNames", testOperationId_acceptsLegacyAndNewNames),
        ("testRoundTrip_accountCreate", testRoundTrip_accountCreate),
        ("testRoundTrip_accountUpdate", testRoundTrip_accountUpdate),
        ("testRoundTrip_accountValidatorProxy", testRoundTrip_accountValidatorProxy),
        ("testRoundTrip_accountValidatorVote", testRoundTrip_accountValidatorVote),
        ("testRoundTrip_award", testRoundTrip_award),
        ("testRoundTrip_benefactorAward", testRoundTrip_benefactorAward),
        ("testRoundTrip_changeRecoveryAccount", testRoundTrip_changeRecoveryAccount),
        ("testRoundTrip_content", testRoundTrip_content),
        ("testRoundTrip_delegateVestingShares", testRoundTrip_delegateVestingShares),
        ("testRoundTrip_escrowApprove", testRoundTrip_escrowApprove),
        ("testRoundTrip_escrowDispute", testRoundTrip_escrowDispute),
        ("testRoundTrip_escrowRelease", testRoundTrip_escrowRelease),
        ("testRoundTrip_escrowTransfer", testRoundTrip_escrowTransfer),
        ("testRoundTrip_inviteRegistration", testRoundTrip_inviteRegistration),
        ("testRoundTrip_receiveAward", testRoundTrip_receiveAward),
        ("testRoundTrip_recoverAccount", testRoundTrip_recoverAccount),
        ("testRoundTrip_requestAccountRecovery", testRoundTrip_requestAccountRecovery),
        ("testRoundTrip_setWithdrawVestingRoute", testRoundTrip_setWithdrawVestingRoute),
        ("testRoundTrip_transfer", testRoundTrip_transfer),
        ("testRoundTrip_transferToVesting", testRoundTrip_transferToVesting),
        ("testRoundTrip_validatorUpdate", testRoundTrip_validatorUpdate),
        ("testRoundTrip_vote", testRoundTrip_vote),
        ("testRoundTrip_withdrawVesting", testRoundTrip_withdrawVesting),
        ("testUnknownMappedOps_decodeAsUnknown", testUnknownMappedOps_decodeAsUnknown),
        ("testVirtual", testVirtual),
        ("testVirtualDecode_authorReward", testVirtualDecode_authorReward),
        ("testVirtualDecode_commentPayoutUpdate", testVirtualDecode_commentPayoutUpdate),
        ("testVirtualDecode_commentReward", testVirtualDecode_commentReward),
        ("testVirtualDecode_curationReward", testVirtualDecode_curationReward),
        ("testVirtualDecode_fillConvertRequest", testVirtualDecode_fillConvertRequest),
        ("testVirtualDecode_fillOrder", testVirtualDecode_fillOrder),
        ("testVirtualDecode_fillTransferFromSavings", testVirtualDecode_fillTransferFromSavings),
        ("testVirtualDecode_fillVestingWithdraw", testVirtualDecode_fillVestingWithdraw),
        ("testVirtualDecode_hardfork", testVirtualDecode_hardfork),
        ("testVirtualDecode_interest", testVirtualDecode_interest),
        ("testVirtualDecode_liquidityReward", testVirtualDecode_liquidityReward),
        ("testVirtualDecode_returnVestingDelegation", testVirtualDecode_returnVestingDelegation),
        ("testVirtualDecode_shutdownValidator", testVirtualDecode_shutdownValidator),
        ("testVirtualDecode_shutdownValidator_legacyName", testVirtualDecode_shutdownValidator_legacyName),
        ("testVirtualDecode_validatorReward", testVirtualDecode_validatorReward),
        ("testVirtualDecode_validatorReward_legacyKeys", testVirtualDecode_validatorReward_legacyKeys),
    ]
}
```

- [ ] **Step 2: Update the `BlockTest.__allTests` array**

Replace the existing block:

```swift
extension BlockTest {
    static let __allTests = [
        ("testCodable", testCodable),
        ("testDecode_signedBlock_acceptsNewValidatorKeys", testDecode_signedBlock_acceptsNewValidatorKeys),
    ]
}
```

- [ ] **Step 3: Add `APITest.__allTests` if absent, or update existing**

If `APITest.__allTests` does not appear in the manifest, add it. Otherwise, update it to include the two new tests. Verify what's currently there:

```bash
grep -n "extension APITest" /Users/babin/Develop/VIZ/viz-swift-lib/Tests/UnitTests/XCTestManifests.swift
```

If no match, add a new block alongside the existing extensions (before the `#if !os(macOS)` block):

```swift
extension APITest {
    static let __allTests = [
        ("testDynamicGlobalProperties_decodesLegacyKeys", testDynamicGlobalProperties_decodesLegacyKeys),
        ("testDynamicGlobalProperties_decodesNewKeys", testDynamicGlobalProperties_decodesNewKeys),
        ("testExtendedAccount_decodesLegacyWitnessKeys", testExtendedAccount_decodesLegacyWitnessKeys),
        // ... any existing APITest methods (e.g., "testEnergy") preserved here ...
    ]
}
```

If `APITest.__allTests` already exists, append the three new entries and keep the existing ones.

- [ ] **Step 4: Add `DeprecatedAliasesTest.__allTests`**

Add a new extension block before the `#if !os(macOS)` line:

```swift
extension DeprecatedAliasesTest {
    static let __allTests = [
        ("testCompiles", testCompiles),
    ]
}
```

- [ ] **Step 5: Register the two new test classes in `__allTests()`**

Inside the `#if !os(macOS)` block at the bottom of the file, add `testCase(APITest.__allTests)` (if it wasn't already there) and `testCase(DeprecatedAliasesTest.__allTests)` to the returned array:

```swift
#if !os(macOS)
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase(APITest.__allTests),
            testCase(AssetTest.__allTests),
            testCase(Base58Test.__allTests),
            testCase(BlockTest.__allTests),
            testCase(ClientTest.__allTests),
            testCase(DeprecatedAliasesTest.__allTests),
            testCase(OperationTest.__allTests),
            testCase(PrivateKeyTest.__allTests),
            testCase(PublicKeyTest.__allTests),
            testCase(Secp256k1Test.__allTests),
            testCase(VIZURLTest.__allTests),
            testCase(Sha2Test.__allTests),
            testCase(SignatureTest.__allTests),
            testCase(VIZEncoderTest.__allTests),
            testCase(TransactionTest.__allTests),
        ]
    }
#endif
```

(Preserve the alphabetical order the file currently uses.)

- [ ] **Step 6: Run all unit tests**

Run: `swift test --filter UnitTests`
Expected: PASS — same suite as the previous task, no manifest-driven changes on macOS, but the manifest is now consistent for Linux CI.

- [ ] **Step 7: Commit**

```bash
git add Tests/UnitTests/XCTestManifests.swift
git commit -m "test: update XCTestManifests for witness→validator renames"
```

---

## Self-review checklist

After all tasks complete, the implementer should verify:

- [ ] **Spec coverage:**
  - 5 Operation struct renames — Tasks 2–6 ✓
  - 5 OperationId case renames + dual-string decode — Task 1 ✓
  - 2 op-field renames (`witness` → `validator` in types 7 and 42) — Tasks 3, 6 ✓
  - 3 Block.swift type changes — Task 7 ✓
  - 2 API.swift type changes — Tasks 8, 9 ✓
  - Client.swift namespace switch — Task 10 ✓
  - Deprecated typealiases + property aliases + init overloads — Tasks 2–9 (per-task), Task 11 (smoke test) ✓
  - Tests: updated existing, dual-decode, canonical encode (via round-trip), OperationId dual-decode, deprecated-alias compile-smoke — Tasks 1–11 ✓
  - Linux manifest — Task 12 ✓

- [ ] **Greppability:**
  - `legacyWitness` / `legacyWitnessSignature` / `legacyCurrentWitness` / `legacyInflationWitnessPercent` / `legacyWitnessesVotedFor` / `legacyWitnessesVoteWeight` / `legacyWitnessVotes` — every dual-key fallback site.
  - `@available(*, deprecated, renamed:` — every Swift-source compat shim.
  - Plus the old `witness_api` string and the `_witness_` / `_witness*` method names remain in `Client.swift` until Phase C cleanup.

- [ ] **Out of scope confirmation:**
  - No new typed Request structs added ✓
  - `chain_properties_update` (op 25) and `versioned_chain_properties_update` (op 46) still decode to `Operation.Unknown` ✓
  - Documentation (README/AGENTS/CLAUDE) untouched ✓
  - Integration tests untouched (they run live against `node.viz.cx`) ✓
