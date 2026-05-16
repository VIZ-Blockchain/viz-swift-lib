# Test Coverage Expansion and Safe Fixes — Design

**Date:** 2026-05-16
**Status:** Approved, ready for implementation plan
**Scope:** unit-test additions to `Tests/UnitTests/` plus minimal, behavior-preserving source fixes

## Background

`viz-swift-lib` is a low-level Swift library for the VIZ blockchain. It was recently modernized (Swift 5.5+, async/await, `actor Client`, broad `Sendable` conformance). The unit-test suite currently has 56 tests, all passing, and covers core paths (key handling, signing, base58, sha2, transaction shape, a handful of operations, basic JSON-RPC error paths). Integration tests exist but hit a live node and are out of scope here.

A walk-through of the source revealed gaps that this design addresses:

- Only ~4 of 50+ `Operation` types have direct encode/decode tests.
- `Asset` string parsing has limited edge-case coverage.
- Several `VIZEncoder` primitive paths (`Bool`, `Date`, `Optional`, `Data`, varint boundaries) are exercised only indirectly.
- A few latent code-quality issues — silent decode fallbacks, asymmetric encode/decode dispatch, a dead debug `print`, a stale Linux-manifest typo — are not currently caught by tests.

## Goals

1. Cover every modeled `Operation` with tests appropriate to its support tier.
2. Strengthen `Asset` and `VIZEncoder` primitive coverage with explicit edge cases.
3. Pin currently-quirky behavior (silent fallbacks, encode asymmetries) in tests plus `// TODO:` source comments so future maintainers see them.
4. Apply only safe, behavior-preserving source corrections this round.
5. Keep the Linux test manifest in sync.

## Non-goals

- Restructuring `Operation.swift` (1,294 LOC) into multiple files.
- Replacing the hand-rolled api-namespace switch in `Client.swift`.
- Adding new RPC requests or modeling new operations (committee, proposal, paid subscription, etc.).
- Public-API signature changes.
- Integration-test changes.
- CI workflow changes (noted issue: `swift test -v` in the workflow currently runs integration tests against the live node — out of scope).

## Approach

**Approach A — extend in place** was selected over a per-domain fixture catalog or fully data-driven JSON fixtures. The existing test helpers in `Tests/UnitTests/Common.swift` (`AssertEncodes`, `AssertDecodes`, `TestDecode`) already support binary + JSON + string round-trips well; this is a coverage push, not a test-infra rewrite. Approach A minimizes review surface and matches existing conventions.

We will introduce one small per-operation fixture helper inside `Tests/UnitTests/Operation.swift` for readability, but not a separate fixtures file.

## Test additions

### `Tests/UnitTests/Operation.swift`

A `fileprivate` fixture helper:

```swift
fileprivate struct OperationFixture<Op: OperationType & Equatable> {
    let value: Op
    let json: String  // canonical snake_case JSON (operation body only)
    let binary: Data  // canonical binary hex (operation body only,
                      //   without the OperationId varint prefix)
}
```

Three test groups, plus an asymmetry test:

1. **Encode-supported operations — full round-trip** (~25 tests, one per op)
   For each op currently handled in `AnyOperation.encode`:
   - `AssertEncodes(fixture.value, fixture.binary)` — binary
   - JSON-shape check against `fixture.json`
   - `AssertDecodes(json: fixture.json, fixture.value)`
   - JSON round-trip through `AnyOperation` (verifies op-id wrapping)

   Encode-supported ops (in encode dispatch order): `Vote`, `Content`, `Transfer`, `TransferToVesting`, `WithdrawVesting`, `AccountCreate`, `AccountUpdate`, `WitnessUpdate`, `AccountWitnessVote`, `AccountWitnessProxy`, `Custom`, `DeleteContent`, `SetWithdrawVestingRoute`, `RequestAccountRecovery`, `RecoverAccount`, `ChangeRecoveryAccount`, `EscrowTransfer`, `EscrowDispute`, `EscrowRelease`, `EscrowApprove`, `DelegateVestingShares`, `Award`, `ReceiveAward` (virtual), `BenefactorAward` (virtual), `InviteRegistration`.

2. **Virtual / decode-only operations — JSON decode only** (~14 tests)
   `AuthorReward`, `CurationReward`, `CommentReward`, `LiquidityReward`, `Interest`, `FillConvertRequest`, `FillVestingWithdraw`, `ShutdownWitness`, `FillOrder`, `FillTransferFromSavings`, `Hardfork`, `CommentPayoutUpdate`, `ReturnVestingDelegation`, `WitnessReward`. Each: feed an `AnyOperation` JSON containing the op id and verify the decoded `operation` is the expected struct with the expected field values.

3. **Unknown-mapped operations — pin current decode-to-`Unknown` behavior** (~27 tests)
   Op ids currently mapped to `Operation.Unknown()` in `AnyOperation.init(from:)`: `account_metadata`, `proposal_create`, `proposal_update`, `proposal_delete`, `chain_properties_update`, `content_payout_update`, `content_benefactor_reward`, `committee_worker_create_request`, `committee_worker_cancel_request`, `committee_vote_request`, `committee_cancel_request`, `committee_approve_request`, `committee_payout_request`, `committee_pay_request`, `use_invite_balance`, `expire_escrow_ratification`, `set_paid_subscription`, `paid_subscribe`, `paid_subscription_action`, `cancel_paid_subscription`, `set_account_price`, `set_subaccount_price`, `buy_account`, `account_sale`, `create_invite`, `claim_invite_balance`, `versioned_chain_properties_update`. Each test: decode the op-id-only JSON and assert the resulting `operation is Operation.Unknown`. This makes the "we don't model this yet" status load-bearing and visible. When any of these is later modeled, the corresponding test fails loudly.

4. **`testEncodeAsymmetry`** (single test, multiple cases)
   Documents the current asymmetric / broken encode paths:
   - `Operation.CustomJson` encode → `XCTAssertThrowsError` (decode produces `CustomJson`, encode dispatches on `Operation.Custom`).
   - `Operation.Convert` encode → `XCTAssertThrowsError` (no `OperationId.convert` case).
   - Other ops defined as types but not in encode dispatch (`ReportOverProduction`, `CommentOptions`, `ChallengeAuthority`, `ProveAuthority`, `TransferToSavings`, `TransferFromSavings`, `CancelTransferFromSavings`, `CustomBinary`, `DeclineVotingRights`, `ResetAccount`, `SetResetAccount`, `ClaimRewardBalance`, `AccountCreateWithDelegation`) → `XCTAssertThrowsError` for each.

   Pinning these makes future fixes (adding the missing dispatch cases / `OperationId` rows) a deliberate, test-failure-driven change.

### `Tests/UnitTests/Asset.swift`

Add:

- Malformed-string init returns `nil`: `""`, `"VIZ"`, `"10.000"`, `"10.000VIZ"`, `"abc VIZ"`, `"10..0 VIZ"`.
- Custom-symbol precision inference: `Asset("10.123456 FOO")` → precision 6; `Asset("10 FOO")` → precision 0; `Asset("10. FOO")` → precision 0 (empty fraction).
- Negative and zero amounts: `Asset(-1.5, .viz)`, `Asset(0, .viz)`.
- Description-precision exactness: `Asset(1, .viz).description == "1.000 VIZ"`, `Asset(1, .vests).description == "1.000000 VESTS"`.
- Binary encoding of `.vests` and `.custom(name:precision:)` with non-trivial precision and short names (padding to 7 bytes).
- Decode failure on `"not an asset"` JSON-string → `XCTAssertThrowsError`.

### `Tests/UnitTests/VIZEncoder.swift`

Add:

- `Bool`: `true` → `Data("01")`, `false` → `Data("00")`.
- `Date` (`UInt32` little-endian seconds since 1970): epoch 0; a known timestamp matching existing fixtures.
- `Optional<UInt16>`: `.some(0xbeef)` → `01 ef be`; `.none` → `00`.
- `Data`: raw append, no length prefix — pin the current contract.
- `appendVarint` boundary values: `0`, `127`, `128`, `16383`, `16384`, `UInt64.max`.
- `Array<UInt16>` of size 200 (varint length prefix is multi-byte: `c8 01`).

### `Tests/UnitTests/XCTestManifests.swift`

- Add new test entries for every new method above.
- Fix the existing typo on line 118 (`SeemURLTest` → `VIZURLTest`).

## Source changes (safe corrections)

1. **`Sources/VIZ/Client.swift:233`** — delete the commented-out debug line:
   ```swift
   //        print(String(data:urlRequest.httpBody!, encoding: .utf8))
   ```

That is the only source-code line changed in this round. Every other latent issue is *pinned* rather than fixed, with a `// TODO:` source comment.

## Pinned quirks (test + source comment, NOT fixed)

For each item below: a test documents current behavior; a one-line `// TODO:` comment is added at the source location explaining the deferred fix.

| Issue | Location | Comment to add |
|---|---|---|
| `API.Share.init(from:)` silently returns `0` on string-parse failure | `Sources/VIZ/API.swift:79–87` | `// TODO: should throw DecodingError on parse failure instead of returning 0` |
| `custom` op id decodes as `CustomJson` but encode switch expects `Custom` | `Sources/VIZ/Operation.swift:1126, 1214` | `// TODO: encode dispatches on Operation.Custom, decode produces Operation.CustomJson — reconcile` |
| `Operation.Convert` has no matching `OperationId` case | `Sources/VIZ/Operation.swift:133–143` | `// TODO: no matching OperationId case — encoding falls through to default` |
| `PublicKey.AddressPrefix.testNet` stringifies to `"VIZ"` like `.mainNet` | `Sources/VIZ/PublicKey.swift:108–109` | `// VIZ has no separate testnet prefix; .testNet currently stringifies to "VIZ" (intentional)` |
| `ExtendedAccount.currentEnergy` reads `Date()` implicitly (not injectable) | `Sources/VIZ/API.swift:144–153` | `// TODO: take a Date parameter for testability` |

## Linux / CI

- `XCTestManifests.swift` is updated in lock-step with new test methods (hand-edited; `swift test --generate-linuxmain` is deprecated in current toolchains and produces the same shape).
- The `SeemURLTest` → `VIZURLTest` typo at line 118 of the manifest is corrected — this entry is inside `#if !os(macOS)`, so the typo currently silently disables `VIZURLTest` on Linux only. Fixing it adds 2 tests' worth of Linux coverage.
- `.github/workflows/tests.yml` runs `swift test -v` (all tests including integration). No workflow changes here; integration tests against `https://node.viz.cx` may flake the badge but that's a separate decision.

## Estimated test deltas

| Area | New tests |
|---|---|
| Operations — encode-supported round-trip | ~25 |
| Operations — virtual decode-only | ~14 |
| Operations — Unknown-mapped pin | ~27 |
| Operations — encode asymmetry (single test, many `XCTAssertThrowsError` cases) | 1 (covers ~15 ops) |
| Asset edge cases | ~12 |
| VIZEncoder primitives | ~8 |
| **Total** | **~87** |

Bringing the suite from 56 → ~143 unit tests.

## Success criteria

- `swift test --filter UnitTests` passes locally.
- The GitHub Actions workflow stays green for `UnitTests` (integration-test flakiness is a separate concern).
- Every operation defined in `Sources/VIZ/Operation.swift` has at least one test referencing it by type, so dead/unmodeled operations become visible.
- Each pinned quirk has both a test and a `// TODO:` comment, so the next maintainer can grep for `TODO:` and find every known issue from this round.
- Total runtime of the unit suite remains under 1 second.

## Open questions / deferred decisions

These are intentionally not addressed this round; recording them so they survive into the next session:

- Fix vs. remove for the asymmetric `Operation.CustomJson` / `Operation.Custom` pair (pick a single canonical type).
- Adding `OperationId.convert` and dispatch case for `Operation.Convert`.
- Modeling the ~15 currently-`Unknown` operation types.
- Splitting `Operation.swift` into per-category files.
- Replacing the `Client.api` method-namespace switch with a declarative table + tests.
- CI: filter the badge workflow to `--filter UnitTests` so it stops depending on live-node reachability.
