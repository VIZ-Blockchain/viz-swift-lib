# HF13/HF14 operations (ids 60–105) — Prediction Markets for viz-swift-lib

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gap between `OperationId` (stops at 59) and the node (105). Add every HF14 Prediction-Market ("Onix") broadcast operation as an encodable/decodable `Operation.*` struct, every PM virtual operation as a decode-only struct, and the HF13 ops 60–65 and HF15 op 105 that sit in the same gap. All binary encodings are verified against the hex vectors shared by viz-python-lib / viz-php-lib / the node.

**Architecture:** Pure extension of the existing single-file pattern in `Sources/VIZ/Operation.swift`: one `public struct` per op inside `extension Operation`, one `OperationId` case, one `init(from:)` name arm, one `AnyOperation` decode arm, one encode arm. No encoder changes are needed: `VIZEncoder` already handles `Int8/Int16/UInt8/UInt16/UInt32/Int64`, `String`, `Bool`, `Date` (uint32 epoch), `Data` (raw bytes), `Optional` (flag byte + value), `Array` (varint count + items) and `Asset`. `chain_properties_pm` is **out of scope**: the library has no chain-properties structs at all (`versioned_chain_properties_update` decodes as `Unknown`), so there is no pattern to extend.

**Tech Stack:** Swift 6.3 toolchain, package tools 5.5, XCTest. `swift test --filter UnitTests` is the gate (integration tests hit a live node and are not part of the loop).

**Branch / PR:** `feat/prediction-market-ops` → `VIZ-Blockchain/viz-swift-lib` `master` (you have admin). Conventional commits; one commit per task.

---

## Protocol reference (from `viz-cpp-node` master `libraries/protocol/include/graphene/protocol/{operations,pm_operations,pm_virtual_operations,chain_operations,chain_virtual_operations,agent_operations}.hpp`)

Wire = fields in FC_REFLECT order; `extensions` = empty set = one `0x00` byte (`[FutureExtensions]` already does this). Swift types: `account_name_type → String`, `share_type / pm_object_id_type → Int64`, `asset → Asset`, `fc::sha256 → Data` (32 bytes; JSON hex via the client's `dataDecoder`), `time_point_sec → Date`, `optional<T> → T?`, `vector<string> → [String]` (unsorted — keep order), `flat_set<string> → [String]` (must be pre-sorted by the caller; encoder does not sort).

### Gap ops (HF13 / HF15)

| id | op | fields | virtual |
|---|---|---|---|
| 60 | `fixed_award` | initiator:String, receiver:String, reward_amount:Asset, max_energy:UInt16, custom_sequence:UInt64, memo:String, beneficiaries:[Beneficiary] | no |
| 61 | `target_account_sale` | account:String, account_seller:String, target_buyer:String, account_offer_price:Asset, account_on_sale:Bool | no |
| 62 | `bid` | account:String, bidder:String, bid:Asset | **yes** |
| 63 | `outbid` | account:String, bidder:String, bid:Asset | **yes** |
| 64 | `set_reward_sharing` | owner:String, sharing_rate:UInt16 | no |
| 65 | `stakeholder_reward` | validator:String, stakeholder:String, shares:Asset | **yes** |
| 105 | `set_agent_permission` | account:String, agent_name:String, agent_key:PublicKey, operations:[String] (flat_set, sorted), expiration:Date, addons:[String] (flat_set, sorted), extensions | no |

### PM broadcast ops (all end with `extensions: [FutureExtensions]`)

| id | op | fields (wire order) |
|---|---|---|
| 66 | `pm_oracle_register` | owner:String, insurance:Asset, fee_percent:UInt16, fixed_fee:Asset, rules_url:String, auto_accept_creator:String, auto_accept_resolver:String, auto_accept:Bool |
| 67 | `pm_oracle_update` | owner:String, insurance_delta:Asset?, fee_percent:UInt16?, fixed_fee:Asset?, rules_url:String?, auto_accept_creator:String?, auto_accept_resolver:String?, auto_accept:Bool? |
| 68 | `pm_create_market` | creator:String, oracle:String, market_type:UInt8, outcomes:[String], url:String, oracle_fee_percent:UInt16, oracle_fixed_fee:Asset, creator_fee_percent:UInt16, liquidity_fee_percent:UInt16, liquidity:Asset, lmsr_b:Int64, betting_expiration:Date, result_expiration:Date, time_penalty_type:UInt8, time_penalty_value:UInt32, penalty_curve_type:UInt8, allow_early_resolution:Bool, allow_cancellation:Bool, allow_batch:Bool, allow_instant_bet:Bool, endogeneity_tier:UInt8, dispute_mode:UInt8, dispute_resolver:String, dispute_penalty_percent:Int16, metadata:String |
| 69 | `pm_oracle_accept_market` | oracle:String, market_id:Int64, accept:Bool, oracle_fee_percent:UInt16, oracle_fixed_fee:Asset |
| 70 | `pm_place_bet` | account:String, market_id:Int64, side:Int8, outcome_index:Int16, amount:Asset, min_tokens:Int64, mode:UInt8 |
| 71 | `pm_commit_bet` | account:String, market_id:Int64, commitment:Data(32), escrow_amount:Asset, no_reveal_fee_percent:UInt16 |
| 72 | `pm_reveal_bet` | account:String, commit_id:Int64, side:Int8, outcome_index:Int16, amount:Asset, salt:String, min_tokens:Int64 |
| 73 | `pm_cancel_bet` | account:String, bet_id:Int64, min_return:Int64 |
| 74 | `pm_add_liquidity` | provider:String, market_id:Int64, amount:Asset |
| 75 | `pm_withdraw_liquidity` | provider:String, liquidity_id:Int64, amount:Asset |
| 76 | `pm_resolve_market` | oracle:String, market_id:Int64, winning_outcome:Int16, decision_url:String, decision_reason:String |
| 77 | `pm_no_contest` | oracle:String, market_id:Int64, reason:String |
| 78 | `pm_dispute_create` | disputer:String, market_id:Int64, proposed_outcome:Int16, reason:String |
| 79 | `pm_dispute_vote` | voter:String, market_id:Int64, vote_outcome:Int16, vote_percent:Int16 (regular authority) |
| 80 | `pm_dispute_resolve` | resolver:String, market_id:Int64, correct_outcome:Int16, penalty_amount:Asset, ban_oracle:Bool, ban_oracle_until:Date, ban_creator:Bool, ban_creator_until:Date |
| 81 | `pm_transfer_position` | from:String, bet_id:Int64, to:String, amount:**Int64** (share weight, not Asset), memo:String |
| 82 | `pm_lazy_deposit` | account:String, amount:Asset |
| 83 | `pm_lazy_withdraw` | account:String, shares:Int64, emergency:Bool |
| 91 | `pm_leverage_open` | account:String, market_id:Int64, outcome_index:Int16, collateral:Asset, loan:Asset, min_tokens:Int64, max_slippage_percent:UInt16 |
| 92 | `pm_leverage_close` | account:String, position_id:Int64, min_return:Int64 |
| 93 | `pm_leverage_convert` | account:String, position_id:Int64, conversion_profit_cost:UInt16 |
| 98 | `pm_dispute_oracle_respond` | oracle:String, market_id:Int64, response:String |
| 99 | `pm_unban` | resolver:String, target:String, unban_oracle:Bool, unban_creator:Bool |

### PM virtual ops (decode-only; `isVirtual { true }`, `let` fields, **no** `extensions`)

| id | op | fields |
|---|---|---|
| 84 | `pm_batch_settle` | market_id:Int64, epoch:UInt32, settled_bets:UInt32 |
| 85 | `pm_commit_forfeit` | account:String, commit_id:Int64, market_id:Int64, penalty:Asset, refund:Asset |
| 86 | `pm_auto_payout` | account:String, market_id:Int64, bet_id:Int64, payout:Asset |
| 87 | `pm_dispute_finalize` | oracle:String, market_id:Int64, winning_outcome:Int16, oracle_penalty:Asset |
| 88 | `pm_dispute_auto_close` | oracle:String, market_id:Int64, oracle_penalty:Asset |
| 89 | `pm_oracle_missed_penalty` | oracle:String, market_id:Int64, slashed:Asset |
| 90 | `pm_lazy_recall` | market_id:Int64, recalled:Asset |
| 94 | `pm_leverage_liquidate` | account:String, position_id:Int64, market_id:Int64, cancel_value:Asset, pool_received:Asset, bettor_received:Asset, reason:UInt8 |
| 95 | `pm_leverage_resolve` | account:String, position_id:Int64, market_id:Int64, won:Bool, pool_received:Asset, bettor_received:Asset, outcome_index:Int16, leverage:UInt16 |
| 96 | `pm_market_accepted` | oracle:String, creator:String, market_id:Int64, oracle_fee_percent:UInt16, oracle_fixed_fee:Asset, self_oracle:Bool |
| 97 | `pm_payout` | account:String, market_id:Int64, bet_id:Int64, side:Int8, outcome_index:Int16, amount:Asset, payout:Asset |
| 100 | `pm_ban_expired` | account:String, oracle:Bool, creator:Bool |
| 101 | `pm_market_expired` | oracle:String, creator:String, market_id:Int64, refunded_liquidity:Asset |
| 102 | `pm_dispute_opened` | oracle:String, disputer:String, market_id:Int64, proposed_outcome:Int16 |
| 103 | `pm_early_exit_claim_paid` | account:String, market_id:Int64, kind:UInt8, outcome_index:UInt8, claimed:Asset, paid:Asset |
| 104 | `pm_lp_payout` | account:String, market_id:Int64, principal:Asset, income:Asset, charge:Asset |

### Golden vectors

`/Users/babin/Develop/VIZ/viz-python-lib/tests/test_pm_operations.py` (`PM_CASES`) holds 23 byte-exact vectors, one per broadcast PM op, as `(name, kwargs, full_hex)`. `full_hex` starts with the varint op id (`42` = 66 … `63` = 99); the Swift `OperationFixture.binary` is the body **without** that prefix, so strip the first byte. JSON for the fixture is the kwargs in snake_case; dates as `"2030-01-01T00:00:00"`, assets as `"1.000 VIZ"`, `commitment` as 64 hex chars, optionals as `null`. Two worth knowing when debugging: `pm_place_bet` `side:1, outcome_index:-1` → `01ffff`; `pm_dispute_resolve` `ban_creator_until: 1970-01-01T00:00:00` → `00000000`.

---

## File map

| File | Change |
|---|---|
| `Sources/VIZ/Operation.swift` | +46 structs (7 gap + 23 PM + 16 PM-virtual), +46 `OperationId` cases, +46 name arms, +46 decode arms, +30 encode arms (virtual ops are never encoded — follow what the file does for existing virtual ops) |
| `Tests/UnitTests/Operation.swift` | +23 `roundTrip` fixtures from the python vectors, +3 virtual-decode tests, +2 gap-op fixtures |
| `Tests/UnitTests/XCTestManifests.swift` | register new tests |
| `README.md` | ops list / supported-hardfork note |
| `CHANGELOG.md` (if present) | entry |

---

## Task 1: Gap ops 60–65 and 105

- [ ] Read the existing `Award` (47) and `AccountSale` (57) structs and the virtual-op pattern (`isVirtual`, line ~911) — copy them.
- [ ] Add `FixedAward`, `TargetAccountSale`, `Bid` (virtual), `Outbid` (virtual), `SetRewardSharing`, `StakeholderReward` (virtual), `SetAgentPermission` structs.
- [ ] `OperationId`: cases `fixed_award = 60 … stakeholder_reward = 65`, `set_agent_permission = 105`. Keep `unknown = 255`.
- [ ] Name-switch, decode-switch, encode-switch arms.
- [ ] Fixtures: `fixed_award` and `set_reward_sharing` round-trips; compute expected hex by hand from the table (or with viz-python-lib: `python3 -c "from viz.operations import SetRewardSharing; ..."`), and one `assertVirtualDecodes` for `stakeholder_reward`.
- [ ] `swift test --filter UnitTests` green. Commit `feat: add HF13/HF15 operations 60-65 and 105`.

## Task 2: PM broadcast structs (66–83, 91–93, 98–99)

- [ ] Add the 23 structs in id order under a `// MARK: - Prediction markets (HF14)` block. `public var` fields, memberwise `public init` with defaults mirroring the node (`side: Int8 = -1`, `outcomeIndex: Int16 = -1`, `minTokens: Int64 = 0`, `mode: UInt8 = 0`, `allowInstantBet: Bool = true`, `endogeneityTier: UInt8 = 2`, `extensions: [FutureExtensions] = []`). CamelCase property names; the client's `.convertFromSnakeCase` / `.convertToSnakeCase` handles JSON.
- [ ] `PmCommitBet.commitment: Data` — add a `precondition`-free doc comment "32 bytes (sha256)"; no validation (node validates).
- [ ] `PmOracleUpdate` optionals are plain `T?` — `Optional: VIZEncodable` already emits the flag byte. Verify `Asset?` encodes (Asset is `VIZEncodable`, so it does).
- [ ] `OperationId` cases + three switches.
- [ ] Fixtures: all 23 python vectors as `OperationFixture` + `roundTrip`. Put the JSON literals verbatim from the python kwargs. These are the consensus guard; do not "fix" a vector to match the code.
- [ ] Green. Commit `feat: add HF14 prediction-market broadcast operations`.

## Task 3: PM virtual structs (84–90, 94–97, 100–104)

- [ ] 16 structs with `let` fields, `isVirtual { true }`, no extensions, no encode arm.
- [ ] `OperationId` cases + name arms + decode arms.
- [ ] Tests: `assertVirtualDecodes` for `pm_payout` (has Int8 + Int16 + two assets), `pm_leverage_resolve` (Bool + UInt16), `pm_lp_payout`. Also one test that decoding a `[105, {...}]`-shaped unknown-id op still yields `.unknown`/`Unknown` as today.
- [ ] Green. Commit `feat: decode HF14 prediction-market virtual operations`.

## Task 4: Manifest, docs, PR

- [ ] `Tests/UnitTests/XCTestManifests.swift`: add every new test method (CI on Linux needs it).
- [ ] `README.md`: extend the supported-operations list; one `PmPlaceBet` usage snippet next to the existing transfer example.
- [ ] `swift build && swift test --filter UnitTests`; run `swiftformat`/`swiftlint` if the repo configures them (check `.swiftlint.yml` / `.swiftformat`).
- [ ] `git push -u origin feat/prediction-market-ops && gh pr create --base master --title "feat: HF14 prediction-market operations (ids 60-105)"`. Body: id ranges, note that encodings are byte-verified against viz-python-lib vectors, link `viz-cpp-node/docs/protocol/operations/prediction-markets.md`.

## Out of scope (follow-ups)

- `chain_properties_pm` / any chain-properties struct — library has none today.
- Typed `prediction_market_api` read wrappers (`get_market`, `list_markets`, `get_account_positions`, `get_oracle`, …) — reachable via `Client.send` with the raw method name after adding `prediction_market_api` to the namespace switch in `Client.swift` (one line; do it if a consumer asks).
