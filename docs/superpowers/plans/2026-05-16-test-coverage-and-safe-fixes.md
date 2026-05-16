# Test Coverage Expansion and Safe Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the `viz-swift-lib` unit-test suite from 56 → ~143 tests by covering every modeled `Operation`, hardening `Asset` and `VIZEncoder` primitive coverage, and pinning known quirks with tests + `// TODO:` comments. Apply only one safe source correction (remove a dead `print` line).

**Architecture:** Extend existing test files in place using the established `AssertEncodes` / `AssertDecodes` helpers in `Tests/UnitTests/Common.swift`. Introduce a single `fileprivate OperationFixture<Op>` helper inside `Tests/UnitTests/Operation.swift` to keep per-op round-trips compact. No new test files, no test-infra rewrites.

**Tech Stack:** Swift 5.5+, XCTest, Swift Package Manager (`swift test`).

**Spec:** `docs/superpowers/specs/2026-05-16-test-coverage-and-safe-fixes-design.md`

---

## File Structure

**Modified (source):**
- `Sources/VIZ/Client.swift` — remove one dead commented line
- `Sources/VIZ/API.swift` — add 2 `// TODO:` comments
- `Sources/VIZ/Operation.swift` — add 2 `// TODO:` comments
- `Sources/VIZ/PublicKey.swift` — add 1 explanatory `//` comment

**Modified (tests):**
- `Tests/UnitTests/Operation.swift` — add fixture helper + ~57 new tests
- `Tests/UnitTests/Asset.swift` — add ~12 new tests
- `Tests/UnitTests/VIZEncoder.swift` — add ~8 new tests
- `Tests/UnitTests/XCTestManifests.swift` — add manifest entries, fix `SeemURLTest` → `VIZURLTest` typo

**Created:** none.

---

## Conventions used in this plan

- All `swift test` runs are against the `UnitTests` target unless noted: `swift test --filter UnitTests`.
- For new binary-encode tests, the engineer writes a fixture with `Data("")` for `.binary`, runs the test once to capture the actual hex from the XCTAssertEqual failure, pastes the captured hex back, and re-runs to confirm pass. This is the **snapshot-pin** pattern used throughout this plan. Before pasting, do a quick sanity check: the hex should contain ASCII bytes of the embedded account names (e.g. `666f6f` for "foo"), recognizable asset suffixes (e.g. `56495a` for "VIZ"), and a length-prefix varint that matches the field count. If a fixture looks wrong on sight, stop and investigate before pinning.
- Existing tests in `Operation.swift` (the old `testEncodable` / `testDecodable`) stay untouched — new per-op tests are added alongside.

---

## Task 1: Source corrections and TODO comments

**Files:**
- Modify: `Sources/VIZ/Client.swift:233`
- Modify: `Sources/VIZ/API.swift:79-87` (add comment), `Sources/VIZ/API.swift:144-153` (add comment)
- Modify: `Sources/VIZ/Operation.swift:133` (add comment on Convert), `Sources/VIZ/Operation.swift:1126` (add comment on custom decode), `Sources/VIZ/Operation.swift:1214` (add comment on Custom encode)
- Modify: `Sources/VIZ/PublicKey.swift:107-109` (add explanatory comment)

- [ ] **Step 1: Delete the dead `print` line in `Client.swift`**

In `Sources/VIZ/Client.swift`, locate line 233 (inside `urlRequest(for:)`):

```swift
        urlRequest.httpBody = try encoder.encode(payload)
//        print(String(data:urlRequest.httpBody!, encoding: .utf8))
        return urlRequest
```

Remove the commented-out `print` line entirely so the two remaining lines sit flush.

- [ ] **Step 2: Add TODO on `API.Share.init(from:)`**

In `Sources/VIZ/API.swift`, locate the `Share` struct (around line 72). Modify its `init(from:)`:

```swift
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int64.self) {
                self.value = intValue
            } else {
                // TODO: should throw DecodingError on parse failure instead of returning 0
                self.value = Int64(try container.decode(String.self)) ?? 0
            }
        }
```

- [ ] **Step 3: Add TODO on `ExtendedAccount.currentEnergy`**

In `Sources/VIZ/API.swift`, locate `currentEnergy` (around line 144). Add a comment line directly above the property declaration:

```swift
        // TODO: take a Date parameter for testability instead of reading Date() implicitly
        public var currentEnergy: Int {
            let deltaTime = Date().timeIntervalSince(lastVoteTime)
```

- [ ] **Step 4: Add TODO on `Operation.Convert`**

In `Sources/VIZ/Operation.swift`, locate the `Convert` struct (around line 133). Add a comment above the struct:

```swift
    // TODO: no matching OperationId case — encoding falls through to default and throws
    /// Convert operation.
    public struct Convert: OperationType, Equatable {
```

- [ ] **Step 5: Add TODO on the `custom` decode / `Custom` encode asymmetry**

In `Sources/VIZ/Operation.swift`, locate `AnyOperation.init(from:)` and find the `case .custom:` line (around line 1126). Update:

```swift
        // TODO: encode dispatches on Operation.Custom, decode produces Operation.CustomJson — reconcile
        case .custom: op = try container.decode(Operation.CustomJson.self)
```

And in the same file, locate the encode dispatch `case let op as Operation.Custom:` (around line 1214). Add a comment above it:

```swift
        // TODO: paired with the decode-side TODO above — pick one canonical type for the `custom` op id
        case let op as Operation.Custom:
            try container.encode(OperationId.custom)
            try container.encode(op)
```

- [ ] **Step 6: Add explanatory comment on `PublicKey.AddressPrefix`**

In `Sources/VIZ/PublicKey.swift`, locate the `description` switch (around line 107). Add a comment above the `.testNet` case:

```swift
        switch self {
        case .mainNet:
            return "VIZ"
        // VIZ has no separate testnet prefix; .testNet currently stringifies to "VIZ" (intentional)
        case .testNet:
            return "VIZ"
        case let .custom(prefix):
            return prefix.uppercased()
        }
```

- [ ] **Step 7: Verify everything still builds and tests pass**

Run: `swift test --filter UnitTests`
Expected: `Executed 56 tests, with 0 failures`.

- [ ] **Step 8: Commit**

```bash
git add Sources/VIZ/Client.swift Sources/VIZ/API.swift Sources/VIZ/Operation.swift Sources/VIZ/PublicKey.swift
git commit -m "chore: remove dead print line and pin known quirks with TODOs

Deletes the commented-out debug print in Client.urlRequest and adds
TODO/explanatory comments at five known-quirk locations (Share decode
fallback, currentEnergy clock injection, Operation.Convert missing
OperationId, custom/CustomJson encode-decode asymmetry, testNet prefix
collision). No behavior changes."
```

---

## Task 2: OperationFixture helper

**Files:**
- Modify: `Tests/UnitTests/Operation.swift` (append helper at top of file, after existing imports and before the existing fileprivate `vote` constant)

- [ ] **Step 1: Add the fixture struct and round-trip helper**

Open `Tests/UnitTests/Operation.swift`. After the `import XCTest` line and before the existing `fileprivate let vote = ...`, insert:

```swift
fileprivate struct OperationFixture<Op: OperationType & Equatable & Decodable> {
    let value: Op
    let json: String        // canonical snake_case JSON of the operation body
    let binary: Data        // canonical binary hex of the operation body (no OperationId prefix)
    let opIdName: String    // string form of the op id, e.g. "vote", used for AnyOperation wrapping
}

fileprivate func roundTrip<Op>(_ fixture: OperationFixture<Op>, file: StaticString = #file, line: UInt = #line) {
    // 1. Binary encode
    AssertEncodes(fixture.value, fixture.binary, file: file, line: line)
    // 2. JSON decode
    AssertDecodes(json: fixture.json, fixture.value, file: file, line: line)
    // 3. AnyOperation round-trip: wrap [op_id, body] JSON, decode, expect matching op
    let wrappedJSON = "[\"\(fixture.opIdName)\",\(fixture.json)]"
    do {
        let any = try TestDecode(AnyOperation.self, json: wrappedJSON)
        guard let decoded = any.operation as? Op else {
            XCTFail("AnyOperation decoded to \(type(of: any.operation)), expected \(Op.self)", file: file, line: line)
            return
        }
        XCTAssertEqual(decoded, fixture.value, file: file, line: line)
    } catch {
        XCTFail("AnyOperation decode failed: \(error)", file: file, line: line)
    }
}
```

- [ ] **Step 2: Verify the suite still builds and passes**

Run: `swift test --filter UnitTests`
Expected: `Executed 56 tests, with 0 failures` (the new helper is unused so far).

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/Operation.swift
git commit -m "test: add OperationFixture helper and roundTrip assertion for op tests"
```

---

## Task 3: Round-trip tests for encode-supported operations

**Files:**
- Modify: `Tests/UnitTests/Operation.swift` (add 25 new test methods inside `class OperationTest`)

Per the spec, the encode-supported set is: `Vote`, `Content`, `Transfer`, `TransferToVesting`, `WithdrawVesting`, `AccountCreate`, `AccountUpdate`, `WitnessUpdate`, `AccountWitnessVote`, `AccountWitnessProxy`, `Custom`, `DeleteContent`, `SetWithdrawVestingRoute`, `RequestAccountRecovery`, `RecoverAccount`, `ChangeRecoveryAccount`, `EscrowTransfer`, `EscrowDispute`, `EscrowRelease`, `EscrowApprove`, `DelegateVestingShares`, `Award`, `ReceiveAward`, `BenefactorAward`, `InviteRegistration`.

Two of those (`AccountUpdate`, `Award`) need shared helper values that already exist in `Tests/UnitTests/API.swift` and `Tests/IntegrationTests/API.swift`. Reuse the public-key strings from those files in your fixtures.

The pattern below is **identical for every op** — only the fixture data differs. Do them one at a time, capturing the binary hex via the snapshot-pin workflow described in "Conventions".

- [ ] **Step 1: Add a `testRoundTrip_vote` method**

Inside `class OperationTest`, append:

```swift
    func testRoundTrip_vote() {
        let fx = OperationFixture(
            value: Operation.Vote(voter: "foo", author: "bar", permlink: "baz", weight: 1000),
            json: "{\"voter\":\"foo\",\"author\":\"bar\",\"permlink\":\"baz\",\"weight\":1000}",
            binary: Data(""),
            opIdName: "vote"
        )
        roundTrip(fx)
    }
```

- [ ] **Step 2: Run and capture the binary hex**

Run: `swift test --filter UnitTests.OperationTest/testRoundTrip_vote`
Expected: FAIL with a message like `XCTAssertEqual failed: ("03666f6f036261720362617ae803") is not equal to ("")`.

Copy the actual hex (the left-hand side of the equality), and replace `Data("")` in the fixture with `Data("03666f6f036261720362617ae803")`.

Sanity check: `666f6f` = "foo", `626172` = "bar", `62617a` = "baz", `e803` = 1000 little-endian. Good.

- [ ] **Step 3: Re-run to confirm pass**

Run: `swift test --filter UnitTests.OperationTest/testRoundTrip_vote`
Expected: `Test Case '-[UnitTests.OperationTest testRoundTrip_vote]' passed`.

- [ ] **Step 4: Add the remaining 24 round-trip tests**

For each operation below, repeat Steps 1-3 with the appropriate fixture. All test methods go inside `class OperationTest`. Naming: `testRoundTrip_<lowerCamelOpName>`.

For multi-line JSON / complex authority literals, reuse `PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!` style helpers already used in `Tests/UnitTests/API.swift` and `Tests/UnitTests/Operation.swift`.

Each fixture entry:

```swift
    func testRoundTrip_content() {
        let fx = OperationFixture(
            value: Operation.Content(
                title: "Hello",
                body: "World",
                author: "alice",
                permlink: "hello-world",
                parentAuthor: "",
                parentPermlink: "ru--general",
                jsonMetadata: "{}"
            ),
            json: "{\"parent_author\":\"\",\"parent_permlink\":\"ru--general\",\"author\":\"alice\",\"permlink\":\"hello-world\",\"title\":\"Hello\",\"body\":\"World\",\"json_metadata\":\"{}\"}",
            binary: Data(""),
            opIdName: "content"
        )
        roundTrip(fx)
    }

    func testRoundTrip_transfer() {
        let fx = OperationFixture(
            value: Operation.Transfer(from: "foo", to: "bar", amount: Asset(10, .viz), memo: "baz"),
            json: "{\"from\":\"foo\",\"to\":\"bar\",\"amount\":\"10.000 VIZ\",\"memo\":\"baz\"}",
            binary: Data(""),
            opIdName: "transfer"
        )
        roundTrip(fx)
    }

    func testRoundTrip_transferToVesting() {
        let fx = OperationFixture(
            value: Operation.TransferToVesting(from: "alice", to: "bob", amount: Asset(5, .viz)),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"amount\":\"5.000 VIZ\"}",
            binary: Data(""),
            opIdName: "transfer_to_vesting"
        )
        roundTrip(fx)
    }

    func testRoundTrip_withdrawVesting() {
        let fx = OperationFixture(
            value: Operation.WithdrawVesting(account: "alice", vestingShares: Asset(100, .vests)),
            json: "{\"account\":\"alice\",\"vesting_shares\":\"100.000000 VESTS\"}",
            binary: Data(""),
            opIdName: "withdraw_vesting"
        )
        roundTrip(fx)
    }

    func testRoundTrip_accountCreate() {
        let masterKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let activeKey = PublicKey("VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6")!
        let regularKey = PublicKey("VIZ5oPsxWgfCH2FWqcXBWeeMmZoyBY5baiuV1vQWMxVVpYxEsJ6Hx")!
        let memoKey = PublicKey("VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH")!
        let fx = OperationFixture(
            value: Operation.AccountCreate(
                fee: Asset(10, .viz),
                creator: "viz",
                newAccountName: "newbie",
                master: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[masterKey: 1]]),
                active: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[activeKey: 1]]),
                regular: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[regularKey: 1]]),
                memoKey: memoKey,
                jsonMetadata: ""
            ),
            json: "{\"fee\":\"10.000 VIZ\",\"creator\":\"viz\",\"new_account_name\":\"newbie\",\"master\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",1]]},\"active\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6\",1]]},\"regular\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ5oPsxWgfCH2FWqcXBWeeMmZoyBY5baiuV1vQWMxVVpYxEsJ6Hx\",1]]},\"memo_key\":\"VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH\",\"json_metadata\":\"\"}",
            binary: Data(""),
            opIdName: "account_create"
        )
        roundTrip(fx)
    }

    func testRoundTrip_accountUpdate() {
        let masterKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let memoKey = PublicKey("VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH")!
        let fx = OperationFixture(
            value: Operation.AccountUpdate(
                account: "alice",
                master: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[masterKey: 1]]),
                active: nil,
                regular: nil,
                memoKey: memoKey,
                jsonMetadata: ""
            ),
            json: "{\"account\":\"alice\",\"master_is_set\":true,\"master\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",1]]},\"active_is_set\":false,\"active\":null,\"regular_is_set\":false,\"regular\":null,\"memo_key\":\"VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH\",\"json_metadata\":\"\"}",
            binary: Data(""),
            opIdName: "account_update"
        )
        roundTrip(fx)
    }

    func testRoundTrip_witnessUpdate() {
        let signingKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let fx = OperationFixture(
            value: Operation.WitnessUpdate(
                owner: "alice",
                url: "https://example.com",
                blockSigningKey: signingKey,
                props: Operation.WitnessUpdate.Properties(),
                fee: Asset(0, .viz)
            ),
            json: "{\"owner\":\"alice\",\"url\":\"https:\\/\\/example.com\",\"block_signing_key\":\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",\"props\":{},\"fee\":\"0.000 VIZ\"}",
            binary: Data(""),
            opIdName: "witness_update"
        )
        roundTrip(fx)
    }

    func testRoundTrip_accountWitnessVote() {
        let fx = OperationFixture(
            value: Operation.AccountWitnessVote(account: "alice", witness: "witness1", approve: true),
            json: "{\"account\":\"alice\",\"witness\":\"witness1\",\"approve\":true}",
            binary: Data(""),
            opIdName: "account_witness_vote"
        )
        roundTrip(fx)
    }

    func testRoundTrip_accountWitnessProxy() {
        let fx = OperationFixture(
            value: Operation.AccountWitnessProxy(account: "alice", proxy: "proxy1"),
            json: "{\"account\":\"alice\",\"proxy\":\"proxy1\"}",
            binary: Data(""),
            opIdName: "account_witness_proxy"
        )
        roundTrip(fx)
    }

    func testRoundTrip_custom() {
        let fx = OperationFixture(
            value: Operation.Custom(
                requiredRegularAuths: ["alice"],
                requiredActiveAuths: [],
                id: 7,
                data: Data([0x01, 0x02, 0x03])
            ),
            json: "{\"required_regular_auths\":[\"alice\"],\"required_active_auths\":[],\"id\":7,\"data\":\"010203\"}",
            binary: Data(""),
            opIdName: "custom"
        )
        roundTrip(fx)
    }
```

Continue with the remaining 14 ops following the same pattern:

```swift
    func testRoundTrip_deleteContent() {
        let fx = OperationFixture(
            value: Operation.DeleteContent(author: "alice", permlink: "post"),
            json: "{\"author\":\"alice\",\"permlink\":\"post\"}",
            binary: Data(""),
            opIdName: "delete_content"
        )
        roundTrip(fx)
    }

    func testRoundTrip_setWithdrawVestingRoute() {
        let fx = OperationFixture(
            value: Operation.SetWithdrawVestingRoute(fromAccount: "alice", toAccount: "bob", percent: 5000, autoVest: false),
            json: "{\"from_account\":\"alice\",\"to_account\":\"bob\",\"percent\":5000,\"auto_vest\":false}",
            binary: Data(""),
            opIdName: "set_withdraw_vesting_route"
        )
        roundTrip(fx)
    }

    func testRoundTrip_requestAccountRecovery() {
        let masterKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let fx = OperationFixture(
            value: Operation.RequestAccountRecovery(
                recoveryAccount: "viz",
                accountToRecover: "alice",
                newOwnerAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[masterKey: 1]]),
                extensions: []
            ),
            json: "{\"recovery_account\":\"viz\",\"account_to_recover\":\"alice\",\"new_owner_authority\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",1]]},\"extensions\":[]}",
            binary: Data(""),
            opIdName: "request_account_recovery"
        )
        roundTrip(fx)
    }

    func testRoundTrip_recoverAccount() {
        let newKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let oldKey = PublicKey("VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6")!
        let fx = OperationFixture(
            value: Operation.RecoverAccount(
                accountToRecover: "alice",
                newOwnerAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[newKey: 1]]),
                recentOwnerAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[oldKey: 1]]),
                extensions: []
            ),
            json: "{\"account_to_recover\":\"alice\",\"new_owner_authority\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",1]]},\"recent_owner_authority\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6\",1]]},\"extensions\":[]}",
            binary: Data(""),
            opIdName: "recover_account"
        )
        roundTrip(fx)
    }

    func testRoundTrip_changeRecoveryAccount() {
        let fx = OperationFixture(
            value: Operation.ChangeRecoveryAccount(
                accountToRecover: "alice",
                newRecoveryAccount: "viz",
                extensions: []
            ),
            json: "{\"account_to_recover\":\"alice\",\"new_recovery_account\":\"viz\",\"extensions\":[]}",
            binary: Data(""),
            opIdName: "change_recovery_account"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowTransfer() {
        let fx = OperationFixture(
            value: Operation.EscrowTransfer(
                from: "alice",
                to: "bob",
                agent: "carol",
                escrowId: 1,
                sbdAmount: Asset(0, .viz),
                steemAmount: Asset(5, .viz),
                fee: Asset(0.1, .viz),
                ratificationDeadline: Date(timeIntervalSince1970: 1_700_000_000),
                escrowExpiration: Date(timeIntervalSince1970: 1_700_086_400),
                jsonMeta: ""
            ),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"escrow_id\":1,\"sbd_amount\":\"0.000 VIZ\",\"steem_amount\":\"5.000 VIZ\",\"fee\":\"0.100 VIZ\",\"ratification_deadline\":\"2023-11-14T22:13:20\",\"escrow_expiration\":\"2023-11-15T22:13:20\",\"json_meta\":\"\"}",
            binary: Data(""),
            opIdName: "escrow_transfer"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowDispute() {
        let fx = OperationFixture(
            value: Operation.EscrowDispute(from: "alice", to: "bob", agent: "carol", who: "alice", escrowId: 1),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"who\":\"alice\",\"escrow_id\":1}",
            binary: Data(""),
            opIdName: "escrow_dispute"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowRelease() {
        let fx = OperationFixture(
            value: Operation.EscrowRelease(
                from: "alice", to: "bob", agent: "carol", who: "carol", receiver: "bob",
                escrowId: 1, sbdAmount: Asset(0, .viz), steemAmount: Asset(5, .viz)
            ),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"who\":\"carol\",\"receiver\":\"bob\",\"escrow_id\":1,\"sbd_amount\":\"0.000 VIZ\",\"steem_amount\":\"5.000 VIZ\"}",
            binary: Data(""),
            opIdName: "escrow_release"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowApprove() {
        let fx = OperationFixture(
            value: Operation.EscrowApprove(from: "alice", to: "bob", agent: "carol", who: "carol", escrowId: 1, approve: true),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"who\":\"carol\",\"escrow_id\":1,\"approve\":true}",
            binary: Data(""),
            opIdName: "escrow_approve"
        )
        roundTrip(fx)
    }

    func testRoundTrip_delegateVestingShares() {
        let fx = OperationFixture(
            value: Operation.DelegateVestingShares(delegator: "alice", delegatee: "bob", vestingShares: Asset(1000, .vests)),
            json: "{\"delegator\":\"alice\",\"delegatee\":\"bob\",\"vesting_shares\":\"1000.000000 VESTS\"}",
            binary: Data(""),
            opIdName: "delegate_vesting_shares"
        )
        roundTrip(fx)
    }

    func testRoundTrip_award() {
        let fx = OperationFixture(
            value: Operation.Award(
                initiator: "alice",
                receiver: "bob",
                energy: 100,
                customSequence: 0,
                memo: "thanks",
                beneficiaries: [Operation.Beneficiary(account: "carol", weight: 1000)]
            ),
            json: "{\"initiator\":\"alice\",\"receiver\":\"bob\",\"energy\":100,\"custom_sequence\":0,\"memo\":\"thanks\",\"beneficiaries\":[{\"account\":\"carol\",\"weight\":1000}]}",
            binary: Data(""),
            opIdName: "award"
        )
        roundTrip(fx)
    }

    func testRoundTrip_receiveAward() {
        let fx = OperationFixture(
            value: Operation.ReceiveAward(
                initiator: "alice",
                receiver: "bob",
                customSequence: 0,
                memo: "thanks",
                shares: Asset(0.5, .vests)
            ),
            json: "{\"initiator\":\"alice\",\"receiver\":\"bob\",\"custom_sequence\":0,\"memo\":\"thanks\",\"shares\":\"0.500000 VESTS\"}",
            binary: Data(""),
            opIdName: "receive_award"
        )
        roundTrip(fx)
    }

    func testRoundTrip_benefactorAward() {
        let fx = OperationFixture(
            value: Operation.BenefactorAward(
                initiator: "alice",
                benefactor: "bob",
                receiver: "carol",
                customSequence: 0,
                memo: "thanks",
                shares: Asset(0.5, .vests)
            ),
            json: "{\"initiator\":\"alice\",\"benefactor\":\"bob\",\"receiver\":\"carol\",\"custom_sequence\":0,\"memo\":\"thanks\",\"shares\":\"0.500000 VESTS\"}",
            binary: Data(""),
            opIdName: "benefactor_award"
        )
        roundTrip(fx)
    }

    func testRoundTrip_inviteRegistration() {
        let newKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let fx = OperationFixture(
            value: Operation.InviteRegistration(
                initiator: "invite",
                newAccountName: "alice",
                inviteSecret: "5KVvGJo9HGXoYBFiLbNqckJR8YxrRKApFjmL3PYWQeUNuaRZhXe",
                newAccountKey: newKey
            ),
            json: "{\"initiator\":\"invite\",\"new_account_name\":\"alice\",\"invite_secret\":\"5KVvGJo9HGXoYBFiLbNqckJR8YxrRKApFjmL3PYWQeUNuaRZhXe\",\"new_account_key\":\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\"}",
            binary: Data(""),
            opIdName: "invite_registration"
        )
        roundTrip(fx)
    }
```

Apply the snapshot-pin workflow for each (run, copy hex, paste, re-run).

**Special handling:**
- For `testRoundTrip_witnessUpdate`, the `Operation.WitnessUpdate.Properties` struct is empty (its fields are commented out). If the JSON shape differs (e.g. no `props` key at all), adjust the fixture JSON to match what the existing decoder/encoder actually does — discover via the snapshot-pin workflow on the decode side too: if `AssertDecodes` fails first, capture the message and reconcile.
- For `testRoundTrip_accountUpdate`, JSON encoding of optional `nil` authorities may serialize as `"master":null` or omit the key entirely depending on the encoder. Capture actual output and update the fixture JSON to match.
- If any round-trip test fails on the JSON-decode side instead of the binary side (e.g. snake_case key the encoder produces doesn't match what you wrote), use the failure message to correct your fixture JSON; then re-run.

If a round-trip test reveals a more serious problem than a fixture-text mismatch (e.g. the binary encoder for some op throws), STOP and add the op to Task 5's asymmetry list instead.

- [ ] **Step 5: Run the full operation test class**

Run: `swift test --filter UnitTests.OperationTest`
Expected: all `testRoundTrip_*` methods pass plus the existing `testEncodable` / `testDecodable` / `testVirtual` (29 tests total in the class).

- [ ] **Step 6: Commit**

```bash
git add Tests/UnitTests/Operation.swift
git commit -m "test: add encode-supported operation round-trip coverage (25 ops)

Adds testRoundTrip_<op> for every operation that AnyOperation.encode
dispatches on, verifying binary encode, JSON decode, and AnyOperation
wrapped JSON round-trip in one helper."
```

---

## Task 4: Virtual / decode-only operation tests

**Files:**
- Modify: `Tests/UnitTests/Operation.swift` (add 14 new test methods)

These ops are server-generated; clients only ever decode them. We test JSON decode via `AnyOperation` only.

- [ ] **Step 1: Add a decode-only helper**

Inside `Tests/UnitTests/Operation.swift`, just above `class OperationTest` (next to `roundTrip` helper), append:

```swift
fileprivate func assertVirtualDecodes<Op: OperationType & Equatable>(
    opIdName: String,
    json body: String,
    _ expected: Op,
    file: StaticString = #file,
    line: UInt = #line
) {
    let wrappedJSON = "[\"\(opIdName)\",\(body)]"
    do {
        let any = try TestDecode(AnyOperation.self, json: wrappedJSON)
        guard let decoded = any.operation as? Op else {
            XCTFail("Decoded to \(type(of: any.operation)), expected \(Op.self)", file: file, line: line)
            return
        }
        XCTAssertEqual(decoded, expected, file: file, line: line)
        XCTAssertTrue(decoded.isVirtual, "Expected isVirtual == true", file: file, line: line)
    } catch {
        XCTFail("Decode failed: \(error)", file: file, line: line)
    }
}
```

- [ ] **Step 2: Add the 14 virtual-decode tests**

Append to `class OperationTest`:

```swift
    func testVirtualDecode_authorReward() {
        assertVirtualDecodes(
            opIdName: "author_reward",
            json: "{\"author\":\"alice\",\"permlink\":\"post\",\"sbd_payout\":\"0.000 VIZ\",\"steem_payout\":\"1.000 VIZ\",\"vesting_payout\":\"0.500000 VESTS\"}",
            Operation.AuthorReward(
                author: "alice",
                permlink: "post",
                sbdPayout: Asset(0, .viz),
                steemPayout: Asset(1, .viz),
                vestingPayout: Asset(0.5, .vests)
            )
        )
    }

    func testVirtualDecode_curationReward() {
        assertVirtualDecodes(
            opIdName: "curation_reward",
            json: "{\"curator\":\"alice\",\"reward\":\"0.500000 VESTS\",\"comment_author\":\"bob\",\"comment_permlink\":\"post\"}",
            Operation.CurationReward(curator: "alice", reward: Asset(0.5, .vests), commentAuthor: "bob", commentPermlink: "post")
        )
    }

    func testVirtualDecode_commentReward() {
        assertVirtualDecodes(
            opIdName: "content_reward",
            json: "{\"author\":\"alice\",\"permlink\":\"post\",\"payout\":\"1.000 VIZ\"}",
            Operation.CommentReward(author: "alice", permlink: "post", payout: Asset(1, .viz))
        )
    }

    func testVirtualDecode_liquidityReward() {
        // No matching OperationId enum case — AnyOperation cannot decode this on its own.
        // Verify the struct decodes from a bare body JSON instead.
        AssertDecodes(
            json: "{\"owner\":\"alice\",\"payout\":\"1.000 VIZ\"}",
            Operation.LiquidityReward(owner: "alice", payout: Asset(1, .viz))
        )
    }

    func testVirtualDecode_interest() {
        // Same caveat as LiquidityReward: not reachable through AnyOperation today.
        AssertDecodes(
            json: "{\"owner\":\"alice\",\"interest\":\"1.000 VIZ\"}",
            Operation.Interest(owner: "alice", interest: Asset(1, .viz))
        )
    }

    func testVirtualDecode_fillConvertRequest() {
        AssertDecodes(
            json: "{\"owner\":\"alice\",\"requestid\":1,\"amount_in\":\"1.000 VIZ\",\"amount_out\":\"1.000 VIZ\"}",
            Operation.FillConvertRequest(owner: "alice", requestid: 1, amountIn: Asset(1, .viz), amountOut: Asset(1, .viz))
        )
    }

    func testVirtualDecode_fillVestingWithdraw() {
        assertVirtualDecodes(
            opIdName: "fill_vesting_withdraw",
            json: "{\"from_account\":\"alice\",\"to_account\":\"alice\",\"withdrawn\":\"1.000000 VESTS\",\"deposited\":\"1.000 VIZ\"}",
            Operation.FillVestingWithdraw(fromAccount: "alice", toAccount: "alice", withdrawn: Asset(1, .vests), deposited: Asset(1, .viz))
        )
    }

    func testVirtualDecode_shutdownWitness() {
        assertVirtualDecodes(
            opIdName: "shutdown_witness",
            json: "{\"owner\":\"alice\"}",
            Operation.ShutdownWitness(owner: "alice")
        )
    }

    func testVirtualDecode_fillOrder() {
        AssertDecodes(
            json: "{\"current_owner\":\"alice\",\"current_orderid\":1,\"current_pays\":\"1.000 VIZ\",\"open_owner\":\"bob\",\"open_orderid\":2,\"open_pays\":\"1.000 VIZ\"}",
            Operation.FillOrder(currentOwner: "alice", currentOrderid: 1, currentPays: Asset(1, .viz), openOwner: "bob", openOrderid: 2, openPays: Asset(1, .viz))
        )
    }

    func testVirtualDecode_fillTransferFromSavings() {
        AssertDecodes(
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"amount\":\"1.000 VIZ\",\"request_id\":1,\"memo\":\"\"}",
            Operation.FillTransferFromSavings(from: "alice", to: "bob", amount: Asset(1, .viz), requestId: 1, memo: "")
        )
    }

    func testVirtualDecode_hardfork() {
        assertVirtualDecodes(
            opIdName: "hardfork",
            json: "{\"hardfork_id\":4}",
            Operation.Hardfork(hardforkId: 4)
        )
    }

    func testVirtualDecode_commentPayoutUpdate() {
        AssertDecodes(
            json: "{\"author\":\"alice\",\"permlink\":\"post\"}",
            Operation.CommentPayoutUpdate(author: "alice", permlink: "post")
        )
    }

    func testVirtualDecode_returnVestingDelegation() {
        assertVirtualDecodes(
            opIdName: "return_vesting_delegation",
            json: "{\"account\":\"alice\",\"vesting_shares\":\"1.000000 VESTS\"}",
            Operation.ReturnVestingDelegation(account: "alice", vestingShares: Asset(1, .vests))
        )
    }

    func testVirtualDecode_witnessReward() {
        assertVirtualDecodes(
            opIdName: "witness_reward",
            json: "{\"witness\":\"alice\",\"shares\":\"0.500000 VESTS\"}",
            Operation.WitnessReward(witness: "alice", shares: Asset(0.5, .vests))
        )
    }
```

Note: `LiquidityReward`, `Interest`, `FillOrder`, `FillTransferFromSavings`, `CommentPayoutUpdate` have no matching `OperationId` enum entries that route through `AnyOperation`, so they're tested via `AssertDecodes` directly on the struct rather than `assertVirtualDecodes`. These tests document that the structs themselves decode correctly even though they can't currently arrive through the normal block-history path. If any of these *do* now decode through `AnyOperation` (check `Sources/VIZ/Operation.swift` `AnyOperation.init(from:)`), prefer `assertVirtualDecodes`.

- [ ] **Step 3: Run virtual tests**

Run: `swift test --filter UnitTests.OperationTest/testVirtualDecode`
Expected: all 14 tests pass.

If any fail with "Decoded to Operation.Unknown, expected ...", that's because the op id isn't dispatched in `AnyOperation.init(from:)`. Move that test to `AssertDecodes`-only style (no `AnyOperation` wrapping), like the LiquidityReward example.

- [ ] **Step 4: Commit**

```bash
git add Tests/UnitTests/Operation.swift
git commit -m "test: add virtual/decode-only operation coverage (14 ops)"
```

---

## Task 5: Unknown-mapped operation pin tests

**Files:**
- Modify: `Tests/UnitTests/Operation.swift` (one new test method covering all 27 Unknown-mapped op ids)

- [ ] **Step 1: Add the pin test**

Append to `class OperationTest`:

```swift
    func testUnknownMappedOps_decodeAsUnknown() {
        // These op ids exist in OperationId but AnyOperation.init(from:) maps them to Operation.Unknown.
        // This test pins that current behavior — when any of these is later modeled, the corresponding
        // line will fail and force a deliberate, test-driven update.
        let opIds: [String] = [
            "account_metadata",
            "proposal_create",
            "proposal_update",
            "proposal_delete",
            "chain_properties_update",
            "content_payout_update",
            "content_benefactor_reward",
            "committee_worker_create_request",
            "committee_worker_cancel_request",
            "committee_vote_request",
            "committee_cancel_request",
            "committee_approve_request",
            "committee_payout_request",
            "committee_pay_request",
            "use_invite_balance",
            "expire_escrow_ratification",
            "set_paid_subscription",
            "paid_subscribe",
            "paid_subscription_action",
            "cancel_paid_subscription",
            "set_account_price",
            "set_subaccount_price",
            "buy_account",
            "account_sale",
            "create_invite",
            "claim_invite_balance",
            "versioned_chain_properties_update",
        ]

        for opIdName in opIds {
            // Body is an empty object; any non-Unknown decode would have to read fields and fail.
            // Unknown is an empty struct so an empty body decodes cleanly.
            let json = "[\"\(opIdName)\",{}]"
            do {
                let any = try TestDecode(AnyOperation.self, json: json)
                XCTAssertTrue(
                    any.operation is Operation.Unknown,
                    "Expected \(opIdName) to decode as Operation.Unknown, got \(type(of: any.operation))"
                )
            } catch {
                XCTFail("Decode of \(opIdName) failed: \(error)")
            }
        }
    }
```

- [ ] **Step 2: Run**

Run: `swift test --filter UnitTests.OperationTest/testUnknownMappedOps_decodeAsUnknown`
Expected: PASS.

If a line fails with "Expected X to decode as Operation.Unknown, got Operation.Y", it means a previously-`Unknown` op has been modeled since this plan was written — remove that op id from the list and add a positive decode test for it instead.

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/Operation.swift
git commit -m "test: pin Unknown-mapped operation decode behavior (27 op ids)"
```

---

## Task 6: Encode asymmetry test

**Files:**
- Modify: `Tests/UnitTests/Operation.swift` (one new test method)

- [ ] **Step 1: Add the asymmetry pin test**

Append to `class OperationTest`:

```swift
    func testEncodeAsymmetry_definedButNotEncodable() {
        // These operation types are defined in Operation.swift but AnyOperation.encode does not dispatch
        // on them (or dispatches incorrectly). Each wrap-and-encode attempt is expected to throw today.
        // When any of these is fixed (added to the encode switch or paired correctly with an OperationId),
        // the corresponding XCTAssertThrowsError line will fail and force this test to be updated.

        // 1. Operation.CustomJson — decode side produces it for the `custom` op id, but encode dispatches
        //    on Operation.Custom. So wrapping a CustomJson and encoding throws.
        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.CustomJson(
            requiredAuths: [], requiredPostingAuths: ["alice"], id: "test", json: "{}"
        ))), "CustomJson")

        // 2. Operation.Convert — no OperationId.convert case exists.
        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.Convert(
            owner: "alice", requestid: 1, amount: Asset(1, .viz)
        ))), "Convert")

        // 3. Operations defined as types but missing from the encode dispatch switch.
        let pubKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!
        let auth = Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[pubKey: 1]])

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.CommentOptions(
            author: "alice", permlink: "post", maxAcceptedPayout: Asset(100, .viz),
            percentSteemDollars: 10000, allowVotes: true, allowCurationRewards: true, extensions: []
        ))), "CommentOptions")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.ChallengeAuthority(
            challenger: "alice", challenged: "bob", requireOwner: false
        ))), "ChallengeAuthority")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.ProveAuthority(
            challenged: "alice", requireOwner: false
        ))), "ProveAuthority")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.TransferToSavings(
            from: "alice", to: "bob", amount: Asset(1, .viz), memo: ""
        ))), "TransferToSavings")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.TransferFromSavings(
            from: "alice", requestId: 1, to: "bob", amount: Asset(1, .viz), memo: ""
        ))), "TransferFromSavings")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.CancelTransferFromSavings(
            from: "alice", requestId: 1
        ))), "CancelTransferFromSavings")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.CustomBinary(
            requiredOwnerAuths: [], requiredActiveAuths: [], requiredPostingAuths: [],
            requiredAuths: [], id: "test", data: Data()
        ))), "CustomBinary")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.DeclineVotingRights(
            account: "alice", decline: true
        ))), "DeclineVotingRights")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.ResetAccount(
            resetAccount: "alice", accountToReset: "bob", newOwnerAuthority: auth
        ))), "ResetAccount")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.SetResetAccount(
            account: "alice", currentResetAccount: "bob", resetAccount: "carol"
        ))), "SetResetAccount")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.ClaimRewardBalance(
            account: "alice", rewardSteem: Asset(1, .viz), rewardSbd: Asset(0, .viz), rewardVests: Asset(0.5, .vests)
        ))), "ClaimRewardBalance")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.AccountCreateWithDelegation(
            fee: Asset(1, .viz), delegation: Asset(0, .vests),
            creator: "alice", newAccountName: "bob",
            master: auth, active: auth, regular: auth, memoKey: pubKey
        ))), "AccountCreateWithDelegation")

        XCTAssertThrowsError(try VIZEncoder.encode(AnyOperation(Operation.ReportOverProduction(
            reporter: "alice",
            firstBlock: SignedBlockHeader(
                previous: BlockId(from: try JSONDecoder().decode(BlockId.self, from: Data("\"00000000000000000000000000000000\"".utf8))),
                timestamp: Date(timeIntervalSince1970: 0),
                witness: "w",
                transactionMerkleRoot: Data(),
                extensions: [],
                witnessSignature: Signature(signature: Data(count: 64), recoveryId: 0)
            ),
            secondBlock: SignedBlockHeader(
                previous: BlockId(from: try JSONDecoder().decode(BlockId.self, from: Data("\"00000000000000000000000000000000\"".utf8))),
                timestamp: Date(timeIntervalSince1970: 0),
                witness: "w",
                transactionMerkleRoot: Data(),
                extensions: [],
                witnessSignature: Signature(signature: Data(count: 64), recoveryId: 0)
            )
        ))), "ReportOverProduction")
    }
```

The `ReportOverProduction` construction is awkward because `BlockId` only has a `Decodable` initializer. If this proves too brittle, replace that one `XCTAssertThrowsError` with a comment noting "ReportOverProduction skipped — BlockId has no public initializer; covered indirectly by the encode-dispatch switch's lack of a case."

- [ ] **Step 2: Run**

Run: `swift test --filter UnitTests.OperationTest/testEncodeAsymmetry_definedButNotEncodable`
Expected: PASS (every `XCTAssertThrowsError` succeeds because `AnyOperation.encode` reaches its `default:` branch for these ops).

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/Operation.swift
git commit -m "test: pin encode asymmetry for ops missing from AnyOperation.encode dispatch"
```

---

## Task 7: Asset edge-case tests

**Files:**
- Modify: `Tests/UnitTests/Asset.swift` (add new test methods to `class AssetTest`)

- [ ] **Step 1: Add the edge-case tests**

Append to `class AssetTest`:

```swift
    // MARK: - String parsing edge cases

    func testMalformedStringsReturnNil() {
        XCTAssertNil(Asset(""))
        XCTAssertNil(Asset("VIZ"))
        XCTAssertNil(Asset("10.000"))
        XCTAssertNil(Asset("10.000VIZ"))
        XCTAssertNil(Asset("abc VIZ"))
        XCTAssertNil(Asset("10..0 VIZ"))
    }

    func testCustomSymbolPrecisionInference() {
        let a = Asset("10.123456 FOO")
        XCTAssertEqual(a?.symbol, .custom(name: "FOO", precision: 6))

        let b = Asset("10 FOO")
        XCTAssertEqual(b?.symbol, .custom(name: "FOO", precision: 0))

        let c = Asset("10. FOO")
        XCTAssertEqual(c?.symbol, .custom(name: "FOO", precision: 0))
    }

    func testNegativeAndZero() {
        let neg = Asset(-1.5, .viz)
        XCTAssertEqual(neg.description, "-1.500 VIZ")
        XCTAssertEqual(neg.resolvedAmount, -1.5)

        let zero = Asset(0, .viz)
        XCTAssertEqual(zero.description, "0.000 VIZ")
        XCTAssertEqual(zero.resolvedAmount, 0.0)
    }

    func testDescriptionExactPrecision() {
        XCTAssertEqual(Asset(1, .viz).description, "1.000 VIZ")
        XCTAssertEqual(Asset(1, .vests).description, "1.000000 VESTS")
        XCTAssertEqual(Asset(1, .custom(name: "FOO", precision: 2)).description, "1.00 FOO")
    }

    // MARK: - Binary encoding for non-VIZ symbols

    func testEncodeVestsBinary() {
        AssertEncodes(Asset(1, .vests), Data(""))
    }

    func testEncodeCustomShortSymbolBinary() {
        AssertEncodes(Asset(1, .custom(name: "FOO", precision: 2)), Data(""))
    }

    // MARK: - Decode failure

    func testDecodeFailsOnMalformedString() {
        do {
            _ = try TestDecode(Asset.self, string: "not an asset")
            XCTFail("Expected DecodingError")
        } catch is DecodingError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
```

- [ ] **Step 2: Capture binary fixtures**

Run: `swift test --filter UnitTests.AssetTest`
Expected: `testEncodeVestsBinary` and `testEncodeCustomShortSymbolBinary` FAIL with the actual hex strings.

Snapshot-pin both: copy the actual hex from each failure into `Data("...")`.

Sanity check for vests:
- amount `1.000000 VESTS` → `40420f0000000000` (1_000_000 little-endian Int64)
- precision byte: `06`
- symbol "VESTS" + 2 NUL pad → `5645535453 0000`

Sanity check for "FOO":
- amount `1.00 FOO` → `64000000 00000000` (100 little-endian)
- precision byte: `02`
- symbol "FOO" + 4 NUL pad → `464f4f 00000000`

- [ ] **Step 3: Re-run**

Run: `swift test --filter UnitTests.AssetTest`
Expected: all tests pass (existing 4 + 7 new = 11 total).

- [ ] **Step 4: Commit**

```bash
git add Tests/UnitTests/Asset.swift
git commit -m "test: add Asset string-parsing, precision, and decode-error coverage"
```

---

## Task 8: VIZEncoder primitive tests

**Files:**
- Modify: `Tests/UnitTests/VIZEncoder.swift` (add new test methods to `class VIZEncoderTest`)

- [ ] **Step 1: Add the primitive tests**

Append to `class VIZEncoderTest`:

```swift
    func testBool() {
        AssertEncodes(true, Data("01"))
        AssertEncodes(false, Data("00"))
    }

    func testDate() {
        // UInt32 little-endian seconds since 1970
        AssertEncodes(Date(timeIntervalSince1970: 0), Data("00000000"))
        // 1700000000 = 0x65525400 → little-endian: 00 54 52 65
        AssertEncodes(Date(timeIntervalSince1970: 1_700_000_000), Data("00545265"))
    }

    func testOptional() {
        AssertEncodes(Optional<UInt16>.some(0xbeef), Data("01efbe"))
        AssertEncodes(Optional<UInt16>.none, Data("00"))
    }

    func testRawData() {
        // Data appends raw bytes with NO length prefix (pinned behavior).
        AssertEncodes(Data([0x01, 0x02, 0x03]), Data("010203"))
    }

    func testVarintBoundaries() {
        // appendVarint is internal — use a String which calls it for its length prefix.
        // 0-byte string → length varint of 0 → 0x00
        AssertEncodes("", Data("00"))
        // 127-byte string → length varint of 127 → 0x7f
        let s127 = String(repeating: "a", count: 127)
        AssertEncodes(s127, Data("7f" + String(repeating: "61", count: 127)))
        // 128-byte string → length varint of 128 → 0x80 0x01
        let s128 = String(repeating: "a", count: 128)
        AssertEncodes(s128, Data("8001" + String(repeating: "61", count: 128)))
    }

    func testLargeArrayVarintLength() {
        // 200 UInt16 elements → length prefix is c8 01 (200), followed by 400 bytes of element data.
        let arr = Array(repeating: UInt16(0), count: 200)
        let expectedHex = "c801" + String(repeating: "0000", count: 200)
        AssertEncodes(arr, Data(expectedHex))
    }
```

- [ ] **Step 2: Run**

Run: `swift test --filter UnitTests.VIZEncoderTest`
Expected: all pass (existing 4 + 6 new = 10 total).

If `testDate` fails, the issue is endianness in the comment math — snapshot-pin the actual hex output and update the literal. Same for `testVarintBoundaries` if your understanding of the encoded length disagrees with reality.

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/VIZEncoder.swift
git commit -m "test: add Bool/Date/Optional/Data/varint coverage for VIZEncoder"
```

---

## Task 9: Update XCTestManifests for Linux

**Files:**
- Modify: `Tests/UnitTests/XCTestManifests.swift`

- [ ] **Step 1: Fix the `SeemURLTest` typo**

In `Tests/UnitTests/XCTestManifests.swift`, locate line 118 inside the `#if !os(macOS)` block:

```swift
            testCase(SeemURLTest.__allTests),
```

Replace with:

```swift
            testCase(VIZURLTest.__allTests),
```

- [ ] **Step 2: Update `OperationTest.__allTests`**

Locate `extension OperationTest` (around line 33). Replace its `__allTests` array with the full list including the 25 round-trip, 14 virtual-decode, 1 unknown-pin, and 1 encode-asymmetry tests:

```swift
extension OperationTest {
    static let __allTests = [
        ("testDecodable", testDecodable),
        ("testEncodable", testEncodable),
        ("testEncodeAsymmetry_definedButNotEncodable", testEncodeAsymmetry_definedButNotEncodable),
        ("testRoundTrip_accountCreate", testRoundTrip_accountCreate),
        ("testRoundTrip_accountUpdate", testRoundTrip_accountUpdate),
        ("testRoundTrip_accountWitnessProxy", testRoundTrip_accountWitnessProxy),
        ("testRoundTrip_accountWitnessVote", testRoundTrip_accountWitnessVote),
        ("testRoundTrip_award", testRoundTrip_award),
        ("testRoundTrip_benefactorAward", testRoundTrip_benefactorAward),
        ("testRoundTrip_changeRecoveryAccount", testRoundTrip_changeRecoveryAccount),
        ("testRoundTrip_content", testRoundTrip_content),
        ("testRoundTrip_custom", testRoundTrip_custom),
        ("testRoundTrip_delegateVestingShares", testRoundTrip_delegateVestingShares),
        ("testRoundTrip_deleteContent", testRoundTrip_deleteContent),
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
        ("testRoundTrip_vote", testRoundTrip_vote),
        ("testRoundTrip_withdrawVesting", testRoundTrip_withdrawVesting),
        ("testRoundTrip_witnessUpdate", testRoundTrip_witnessUpdate),
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
        ("testVirtualDecode_shutdownWitness", testVirtualDecode_shutdownWitness),
        ("testVirtualDecode_witnessReward", testVirtualDecode_witnessReward),
    ]
}
```

- [ ] **Step 3: Update `AssetTest.__allTests`**

Locate `extension AssetTest` (line 3) and replace its `__allTests`:

```swift
extension AssetTest {
    static let __allTests = [
        ("testCustomSymbolPrecisionInference", testCustomSymbolPrecisionInference),
        ("testDecodable", testDecodable),
        ("testDecodeFailsOnMalformedString", testDecodeFailsOnMalformedString),
        ("testDescriptionExactPrecision", testDescriptionExactPrecision),
        ("testEncodable", testEncodable),
        ("testEncodeCustomShortSymbolBinary", testEncodeCustomShortSymbolBinary),
        ("testEncodeVestsBinary", testEncodeVestsBinary),
        ("testMalformedStringsReturnNil", testMalformedStringsReturnNil),
        ("testNegativeAndZero", testNegativeAndZero),
        ("testProperties", testProperties),
        ("testEquateable", testEquateable),
    ]
}
```

- [ ] **Step 4: Update `VIZEncoderTest.__allTests`**

Locate `extension VIZEncoderTest` (around line 91) and replace its `__allTests`:

```swift
extension VIZEncoderTest {
    static let __allTests = [
        ("testArray", testArray),
        ("testBool", testBool),
        ("testDate", testDate),
        ("testFixedWidthInteger", testFixedWidthInteger),
        ("testLargeArrayVarintLength", testLargeArrayVarintLength),
        ("testOptional", testOptional),
        ("testRawData", testRawData),
        ("testSortedDict", testSortedDict),
        ("testString", testString),
        ("testVarintBoundaries", testVarintBoundaries),
    ]
}
```

- [ ] **Step 5: Build to ensure manifest compiles on the macOS toolchain too**

Run: `swift build`
Expected: succeeds with no warnings about missing symbols.

(The manifest body is inside `#if !os(macOS)` so it only compiles on Linux, but the per-class `extension XxxTest { static let __allTests = ... }` is compiled on every platform — any typo or missing symbol breaks the macOS build.)

- [ ] **Step 6: Run full unit test suite locally**

Run: `swift test --filter UnitTests`
Expected: `Executed 143 tests, with 0 failures` (or thereabouts — the exact count is OK to vary by ±2 if some ops needed to be skipped per Task 4's note).

- [ ] **Step 7: Commit**

```bash
git add Tests/UnitTests/XCTestManifests.swift
git commit -m "test: update XCTestManifests for new unit tests and fix SeemURLTest typo

The typo on the affected line meant VIZURLTest was silently skipped
on Linux. Fix restores those 2 tests to Linux CI."
```

---

## Task 10: Final validation

- [ ] **Step 1: Run the unit suite end-to-end**

Run: `swift test --filter UnitTests 2>&1 | tail -5`
Expected: `Executed N tests, with 0 failures` where N is roughly 143.

- [ ] **Step 2: Confirm runtime stays under 1 second**

The last line of test output reports total runtime. Expected: total < 1 second. If runtime balloons, the most likely culprit is a fixture with absurdly large array data — check Task 8's `testLargeArrayVarintLength` (200 elements is fine; thousands would not be).

- [ ] **Step 3: Verify all source-side TODOs are reachable**

Run: `grep -n "TODO:" Sources/VIZ/*.swift`
Expected: exactly 5 lines, matching the spec's pinned-quirks table:
- `Sources/VIZ/API.swift` — Share decode fallback
- `Sources/VIZ/API.swift` — currentEnergy clock
- `Sources/VIZ/Operation.swift` — Convert missing OperationId
- `Sources/VIZ/Operation.swift` — custom/CustomJson encode/decode asymmetry (one TODO line, optionally two if you added the paired comment in Task 1 Step 5)

(The `PublicKey.swift` comment is *explanatory*, not a TODO, so it shouldn't appear in this grep.)

- [ ] **Step 4: No commit needed**

Validation only — if any step fails, fix it in a follow-up commit. If everything passes, the implementation is done.

---

## Notes on integration tests

The existing integration tests in `Tests/IntegrationTests/` hit a live node and are out of scope for this plan. The badge in `README.md` currently depends on them being green. If a future round wants to detangle that, see the spec's "Open questions" section.
