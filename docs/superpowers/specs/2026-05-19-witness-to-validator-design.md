# witness → validator migration (Swift)

**Date:** 2026-05-19
**Status:** Draft — pending user approval
**Reference:** `~/Downloads/witness-to-validator-migration-reference.md` (JS/PHP migration doc)

---

## Purpose

Bring `viz-swift-lib` to parity with the JS/PHP libraries' witness→validator terminology migration. The VIZ blockchain has renamed "witness" to "validator" across the entire stack. Binary wire format is unchanged (integer type IDs); only JSON string names change.

This spec covers the rename inside `viz-swift-lib` itself. Two compat dimensions:

1. **JSON wire compat:** decoders accept both old (`witness*`) and new (`validator*`) JSON keys; encoders always write the new keys. Mirrors the JS/PHP approach for one deprecation cycle.
2. **Swift source compat:** old Swift type names and property names are kept as `@available(*, deprecated, renamed:)` aliases for one release cycle so downstream apps get auto-fix warnings instead of compile errors.

## Scope

### In scope

The surfaces in `Sources/` that mention witness today, plus the tests that cover them:

| File | Surfaces |
|---|---|
| `Sources/VIZ/Operation.swift` | 5 op structs (types 6, 7, 8, 30, 42); 5 `OperationId` cases; the string-switch in `OperationId.init(from:)`; the encode/decode dispatch sites; the renamed inner field `witness` in types 7 and 42 |
| `Sources/VIZ/Block.swift` | `_BlockHeader.witness`; `BlockHeader.witness`; `SignedBlockHeader.witness` + `witnessSignature`; `SignedBlock.witness` + `witnessSignature` proxies |
| `Sources/VIZ/API.swift` | `DynamicGlobalProperties.currentWitness`, `.inflationWitnessPercent`; `ExtendedAccount.witnessesVotedFor`, `.witnessesVoteWeight`, `.witnessVotes` |
| `Sources/VIZ/Client.swift` | the `witness_api` namespace mapping switch arm |
| `Tests/UnitTests/Operation.swift` | round-trip + virtual-decode tests for the 5 renamed ops |
| `Tests/UnitTests/Block.swift` | block header decoding test |
| `Tests/UnitTests/API.swift` | `ExtendedAccount` smoke test |
| `Tests/UnitTests/XCTestManifests.swift` | Linux test entries for all renamed tests |

### Out of scope (explicit)

- **No new typed `Request` structs** for `validator_api` methods (`GetActiveValidators`, etc.). Swift currently exposes zero typed witness-API requests; a separate spec can add validator-API requests later if needed.
- **No implementation of `chain_properties_update` (op 25) and `versioned_chain_properties_update` (op 46).** Both currently decode to `Operation.Unknown()`. The chain-properties field renames in §5 of the reference doc (`inflation_witness_percent` → `inflation_validator_percent`, etc.) are therefore invisible to Swift today; they'll land with whatever future spec implements those ops.
- **No changes to README.md / AGENTS.md / CLAUDE.md** beyond updating any code samples that show old names.
- **No record/replay layer for integration tests.** Per existing project decision, `Tests/IntegrationTests/` stays live against `https://node.viz.cx` to detect wire-format drift. After the live node returns new names, the integration tests will naturally cover the new path.

## Approach: Dual-JSON-key decode via manual `init(from:)`

For each struct with a renamed JSON key, drop auto-synthesized `Decodable` and write a hand-rolled `init(from:)` that prefers the new key and falls back to the old key:

```swift
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
        self.account  = try c.decode(String.self, forKey: .account)
        self.approve  = try c.decode(Bool.self,   forKey: .approve)
        self.validator = (try? c.decode(String.self, forKey: .validator))
                      ?? (try c.decode(String.self, forKey: .legacyWitness))
    }

    // Encoder is explicit so we encode only the canonical fields, never .legacyWitness:
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(account,   forKey: .account)
        try c.encode(validator, forKey: .validator)
        try c.encode(approve,   forKey: .approve)
    }
}
```

**Why manual `init(from:)`:**

- Explicit and greppable — searching for `legacyWitness` finds every dual-key site.
- No new public types added to the library surface.
- Trivial to delete during Phase C cleanup (one `CodingKeys` case + one `??` line per field).
- Property-wrapper alternative was rejected: `@DualKey(...)` + `Decodable` auto-synth has known interaction rough edges, and the wrapper would itself become public surface.

**For root-level snake_case structs** (`DynamicGlobalProperties`, `ExtendedAccount`, `BlockHeader`, `SignedBlockHeader`): these currently rely on `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` configured in `Client.swift`. Adding a custom `CodingKeys` enum on these types replaces the auto-derived keys; the manual `init(from:)` decodes through that explicit map. This means we must spell out **all** CodingKey cases for those structs (not just the renamed ones), but that's a one-time line count, not ongoing complexity.

**Implementation gotcha — CodingKey rawValues with `.convertFromSnakeCase`:** that strategy converts JSON keys (e.g. `"current_validator"`) to camelCase form (`"currentValidator"`) *before* matching against CodingKey raw values. So for these snake_case structs, both the canonical and legacy CodingKey rawValues must be the **camelCase** form, not the snake_case JSON form. Example for `DynamicGlobalProperties`:

```swift
enum CodingKeys: String, CodingKey {
    case currentValidator              // rawValue defaults to "currentValidator"; matches JSON "current_validator"
    case legacyCurrentWitness = "currentWitness"  // matches legacy JSON "current_witness"
    // ... all other fields, each rawValue in camelCase form
}
```

The encoder side mirrors this: `keyEncodingStrategy = .convertToSnakeCase` converts camelCase CodingKey rawValues back to snake_case JSON keys on encode, so canonical encoding emits `"current_validator"` automatically.

## Surface changes — detail per file

### `Sources/VIZ/Operation.swift`

**Renamed structs (with deprecated typealias):**

| New struct | Old struct (kept as deprecated typealias) |
|---|---|
| `Operation.ValidatorUpdate` | `Operation.WitnessUpdate` |
| `Operation.AccountValidatorVote` | `Operation.AccountWitnessVote` |
| `Operation.AccountValidatorProxy` | `Operation.AccountWitnessProxy` |
| `Operation.ShutdownValidator` | `Operation.ShutdownWitness` |
| `Operation.ValidatorReward` | `Operation.WitnessReward` |

Each deprecated typealias lives at the end of `Operation.swift` (or alongside the renamed type) in the form:

```swift
extension Operation {
    @available(*, deprecated, renamed: "ValidatorUpdate")
    public typealias WitnessUpdate = ValidatorUpdate
    // ... etc.
}
```

**Renamed fields (with deprecated computed alias on the new type):**

| New type.field | Deprecated alias kept |
|---|---|
| `AccountValidatorVote.validator` | `var witness: String` (delegating computed property) |
| `ValidatorReward.validator` | `var witness: String` (delegating computed property) |

**Renamed init parameter labels (with deprecated init overload):**

- `AccountValidatorVote.init(account:validator:approve:)` — new canonical init
- `AccountValidatorVote.init(account:witness:approve:)` — deprecated, forwards to the new init

`ValidatorReward` has no public init (memberwise-only with `let` properties), so no init overload needed there.

**Dual-key decode** applies to `AccountValidatorVote` and `ValidatorReward` (only these two have a renamed inner field). The other three renamed ops (`ValidatorUpdate`, `AccountValidatorProxy`, `ShutdownValidator`) have no inner field renames — only the outer operation name changes, which is handled by `OperationId` below.

**`OperationId` enum:**

- Rename cases: `witness_update` → `validator_update`, `account_witness_vote` → `account_validator_vote`, `account_witness_proxy` → `account_validator_proxy`, `shutdown_witness` → `shutdown_validator`, `witness_reward` → `validator_reward`. Raw integer values (6, 7, 8, 30, 42) **unchanged**.
- `init(from:)` string switch: add both old and new string cases mapping to the new enum case. Example:
  ```swift
  case "witness_update", "validator_update": self = .validator_update
  ```
- `encode(to:)` writes `"\(self)"`, so it now emits the new name automatically.
- Dispatch sites (`AnyOperation` encode/decode) use the new case names; the renamed struct types appear in their `case let op as Operation.ValidatorUpdate:` lines.

### `Sources/VIZ/Block.swift`

- Rename `_BlockHeader.witness` → `.validator`. (This protocol is `fileprivate`, so no external impact.)
- Rename `BlockHeader.witness` → `.validator`. Add deprecated computed property: `var witness: String { validator }`.
- Rename `SignedBlockHeader.witness` → `.validator`; rename `.witnessSignature` → `.validatorSignature`. Add deprecated computed properties for both old names.
- Rename `SignedBlock` proxies (`.witness`, `.witnessSignature`) → new names + deprecated aliases.
- Manual `init(from:)` for `BlockHeader` and `SignedBlockHeader` with `CodingKeys` covering all fields plus `legacyWitness = "witness"` and `legacyWitnessSignature = "witness_signature"`.

### `Sources/VIZ/API.swift`

- `DynamicGlobalProperties`: rename `currentWitness` → `currentValidator`, `inflationWitnessPercent` → `inflationValidatorPercent`. Manual `init(from:)` with dual-key fallback for both. Deprecated computed aliases for old names.
- `ExtendedAccount`: rename `witnessesVotedFor` → `validatorsVotedFor`, `witnessesVoteWeight` → `validatorsVoteWeight`, `witnessVotes` → `validatorVotes`. Manual `init(from:)` with dual-key fallback for all three. Deprecated computed aliases.

### `Sources/VIZ/Client.swift`

Update the namespace-mapping switch arm (currently line 46) to:

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

Both old and new method names route to the new `validator_api` namespace (per reference doc: old method names remain accepted as deprecated aliases by the node for one release cycle; namespace is now `validator_api`).

## Tests

Tests-first per project AGENTS.md guidance. Each renamed struct/field gets:

### 1. Updated existing tests

Rename test methods, struct construction sites, and expected JSON strings to use new names. Affected files:

- `Tests/UnitTests/Block.swift`: existing `block.witness` / `block.witnessSignature` assertions → new names; existing fixtures already use `"witness"` JSON keys — those stay (now testing the dual-decode legacy path) AND add a sibling fixture using `"validator"` JSON keys.
- `Tests/UnitTests/API.swift`: rename `ExtendedAccount` init parameters.
- `Tests/UnitTests/Operation.swift`: rename the 5 affected test methods (`testRoundTrip_witnessUpdate`, `testRoundTrip_accountWitnessVote`, `testRoundTrip_accountWitnessProxy`, `testVirtualDecode_shutdownWitness`, `testVirtualDecode_witnessReward`) + their JSON string literals (the canonical-encode tests now expect new JSON names).
- `Tests/UnitTests/XCTestManifests.swift`: rename all renamed test entries.

### 2. New dual-decode tests (one per affected struct)

Each affected struct gets a test asserting that JSON with the **old** key still decodes successfully:

- `testDecode_accountValidatorVote_legacyWitnessKey` — JSON `{"account":"alice","witness":"bob","approve":true}` decodes to `AccountValidatorVote(account:"alice", validator:"bob", approve:true)`.
- `testDecode_validatorReward_legacyWitnessKey`
- `testDecode_blockHeader_legacyWitnessKeys` — covers both `witness` and `witness_signature`.
- `testDecode_signedBlockHeader_legacyWitnessKeys`
- `testDecode_dynamicGlobalProperties_legacyWitnessKeys` — covers `current_witness` + `inflation_witness_percent`.
- `testDecode_extendedAccount_legacyWitnessKeys` — covers all three renamed fields.

### 3. New canonical-encode tests

For each affected struct: asserting that round-tripping (or fresh encode) emits the **new** JSON key, never the old. The existing round-trip tests in `Tests/UnitTests/Operation.swift` already cover this for ops once their `json` literal is updated to the new name; we add explicit encode-only assertions for `BlockHeader`/`SignedBlockHeader`/`DynamicGlobalProperties`/`ExtendedAccount` since those don't have round-trip tests today.

### 4. New OperationId dual-decode test

- `testOperationId_acceptsLegacyWitnessNames` — for each of the 5 renamed ops, decode an `AnyOperation` from JSON that uses the old name (`"witness_update"`, `"account_witness_vote"`, etc.) and assert it decodes to the correct new Swift type and emits the new name on re-encode.

### 5. New deprecated-alias compile-smoke test

A single test file (e.g., `Tests/UnitTests/DeprecatedAliases.swift`) that references each deprecated typealias, deprecated property, and deprecated init exactly once. Decorated with `@available(*, deprecated)` at function level to silence the warnings inside the file itself (so the file still compiles cleanly). This pins the compat surface against accidental removal.

### 6. Linux manifest

Update `XCTestManifests.swift` with all renamed and new test entries.

## Migration phases

Per reference doc, the live node already returns the new names (Phase B). So:

- This spec lands the library in **Phase B** posture: decoders accept both, encoders/transactions send the new names by default, Swift source has deprecated aliases.
- A future cleanup spec (Phase C) can remove the `legacy*` CodingKey cases, the deprecated computed properties, the deprecated typealiases, the deprecated init overloads, and the old strings in `Client.swift`'s namespace switch. Greppable by `legacyWitness`, `legacyWitnessSignature`, `@available(*, deprecated, renamed:`, plus the old method names in `Client.swift`.

## Risks and non-obvious notes

- **Source-breaking risk for downstream apps using the integration test pattern.** Anything that imports `VIZ` and references e.g. `block.witness` will compile (deprecated warning) but `block.witnessSignature` likewise. No callers in this repo outside tests.
- **`@available(*, deprecated, renamed:)` on a nested typealias** is supported but Xcode's auto-fix surfaces the unqualified name in some contexts — that's a minor UX concern, not a correctness one.
- **`OperationId` is `fileprivate`** — renaming its cases has no external impact even though the rename touches many lines.
- **Dual-decode is decode-only.** Any future code that constructs an `AccountWitnessVote` typealias still actually constructs an `AccountValidatorVote`, which encodes as `{"validator":…}`. There is no way to ask the encoder to emit the legacy key. This is intentional — sending the new name is always safe.
- **Live integration tests** against `https://node.viz.cx` will naturally exercise the new-name decode path. If any test there grep-references `witness`, it'll need updating; this should be checked during implementation (out of scope for this spec to enumerate).

## Acceptance

The change is complete when:

1. All renamed surfaces above use the new names; old names exist only as `@available(*, deprecated, renamed:)` shims.
2. All existing tests pass with the renamed code (encoders write new names).
3. All new dual-decode tests pass (decoders accept both old and new names).
4. The deprecated-alias compile-smoke test compiles and runs.
5. Linux `XCTestManifests.swift` is updated; CI test job stays green (unit tests filter unchanged).
6. Integration tests pass against the live node.
