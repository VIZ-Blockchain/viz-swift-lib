@testable import VIZ
import XCTest

/// Compile-smoke + behavioural test: every deprecated alias / property / init
/// introduced by the witness → validator migration (Tasks 2–9) is referenced
/// here and asserted equal to its canonical replacement.
///
/// The class itself is marked deprecated so that warnings emitted by the
/// deprecated references inside it are silenced — Swift suppresses deprecation
/// diagnostics inside contexts that are themselves deprecated. The build
/// should therefore produce ZERO deprecation warnings from this file.
///
/// If any deprecated symbol is removed during Phase C cleanup, this file
/// fails to compile.
@available(*, deprecated, message: "Compile-smoke test for witness→validator migration aliases.")
class DeprecatedAliasesTest: XCTestCase {

    // MARK: - Operation typealiases

    func testOperationTypealiases() {
        // Each deprecated typealias must resolve to its canonical type.
        let signingKey = PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!

        let oldUpdate: VIZ.Operation.WitnessUpdate = VIZ.Operation.WitnessUpdate(
            owner: "alice",
            url: "https://example.com",
            blockSigningKey: signingKey,
            props: VIZ.Operation.WitnessUpdate.Properties(),
            fee: Asset(0, .viz)
        )
        let newUpdate = VIZ.Operation.ValidatorUpdate(
            owner: "alice",
            url: "https://example.com",
            blockSigningKey: signingKey,
            props: VIZ.Operation.ValidatorUpdate.Properties(),
            fee: Asset(0, .viz)
        )
        XCTAssertEqual(oldUpdate, newUpdate)

        let oldVote: VIZ.Operation.AccountWitnessVote = VIZ.Operation.AccountWitnessVote(
            account: "alice", validator: "bob", approve: true
        )
        let newVote = VIZ.Operation.AccountValidatorVote(
            account: "alice", validator: "bob", approve: true
        )
        XCTAssertEqual(oldVote, newVote)

        let oldProxy: VIZ.Operation.AccountWitnessProxy = VIZ.Operation.AccountWitnessProxy(
            account: "alice", proxy: "proxy1"
        )
        let newProxy = VIZ.Operation.AccountValidatorProxy(account: "alice", proxy: "proxy1")
        XCTAssertEqual(oldProxy, newProxy)

        let oldShutdown: VIZ.Operation.ShutdownWitness = VIZ.Operation.ShutdownWitness(owner: "alice")
        let newShutdown = VIZ.Operation.ShutdownValidator(owner: "alice")
        XCTAssertEqual(oldShutdown, newShutdown)

        let oldReward: VIZ.Operation.WitnessReward = VIZ.Operation.WitnessReward(
            validator: "alice", shares: Asset(0.5, .vests)
        )
        let newReward = VIZ.Operation.ValidatorReward(
            validator: "alice", shares: Asset(0.5, .vests)
        )
        XCTAssertEqual(oldReward, newReward)
    }

    // MARK: - Operation deprecated init overloads + computed properties

    func testOperationDeprecatedInits() {
        // Deprecated init with `witness:` label on AccountValidatorVote.
        let vote = VIZ.Operation.AccountValidatorVote(account: "a", witness: "b", approve: true)
        XCTAssertEqual(vote.validator, "b")
        XCTAssertEqual(vote.witness, "b") // deprecated computed property forwards to validator

        // Mutating setter on AccountValidatorVote.witness forwards to validator.
        var voteMutable = vote
        voteMutable.witness = "c"
        XCTAssertEqual(voteMutable.validator, "c")
        XCTAssertEqual(voteMutable.witness, "c")

        // Deprecated init with `witness:` label on ValidatorReward.
        let reward = VIZ.Operation.ValidatorReward(witness: "a", shares: Asset(0.5, .vests))
        XCTAssertEqual(reward.validator, "a")
        XCTAssertEqual(reward.witness, "a") // deprecated computed property forwards to validator
    }

    // MARK: - BlockHeader / SignedBlockHeader / SignedBlock deprecated properties

    func testBlockHeaderDeprecatedProperties() throws {
        let signedBlock = try TestDecode(SignedBlock.self, json: signedBlockJSON)

        // SignedBlock proxies header through its own deprecated computed props.
        XCTAssertEqual(signedBlock.witness, signedBlock.validator)
        XCTAssertEqual(signedBlock.witnessSignature, signedBlock.validatorSignature)
        XCTAssertEqual(signedBlock.witness, "steempty")

        // Decode a bare SignedBlockHeader from the same fixture's header fields.
        let signedHeader = try TestDecode(SignedBlockHeader.self, json: signedHeaderJSON)
        XCTAssertEqual(signedHeader.witness, signedHeader.validator)
        XCTAssertEqual(signedHeader.witnessSignature, signedHeader.validatorSignature)

        // Decode a bare BlockHeader (no signature field).
        let header = try TestDecode(BlockHeader.self, json: headerJSON)
        XCTAssertEqual(header.witness, header.validator)
        XCTAssertEqual(header.witness, "steempty")
    }

    // MARK: - API deprecated properties

    func testApiDeprecatedProperties() throws {
        let dgp = try TestDecode(API.DynamicGlobalProperties.self, json: dgpJSON)
        XCTAssertEqual(dgp.currentWitness, dgp.currentValidator)
        XCTAssertEqual(dgp.currentWitness, "alice")
        XCTAssertEqual(dgp.inflationWitnessPercent, dgp.inflationValidatorPercent)
        XCTAssertEqual(dgp.inflationWitnessPercent, 1500)

        let acc = try TestDecode(API.ExtendedAccount.self, json: extendedAccountJSON)
        XCTAssertEqual(acc.witnessesVotedFor, acc.validatorsVotedFor)
        XCTAssertEqual(acc.witnessesVotedFor, 3)
        XCTAssertEqual(acc.witnessesVoteWeight.value, acc.validatorsVoteWeight.value)
        XCTAssertEqual(acc.witnessesVoteWeight.value, 42)
        XCTAssertEqual(acc.witnessVotes, acc.validatorVotes)
        XCTAssertEqual(acc.witnessVotes, ["carol"])
    }
}

// MARK: - Fixtures

fileprivate let signedBlockJSON = """
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

fileprivate let signedHeaderJSON = """
{
  "previous": "001e847f77b2d0bc1c29caf02b1a98d79aefb7ad",
  "timestamp": "2016-06-02T23:58:45",
  "validator": "steempty",
  "transaction_merkle_root": "3335e6efe04f09aac61ad1fcc241ada1e1e8fc62",
  "extensions": [],
  "validator_signature": "1f26706cb7da8528a303f55c7e260b8b43ba2aaddb2970d01563f5b1d1dc1d8e0342e4afe22e95277d37b4e7a429df499771f8db064e64aa964a0ba4a17a18fb2b"
}
"""

fileprivate let headerJSON = """
{
  "previous": "001e847f77b2d0bc1c29caf02b1a98d79aefb7ad",
  "timestamp": "2016-06-02T23:58:45",
  "validator": "steempty",
  "transaction_merkle_root": "3335e6efe04f09aac61ad1fcc241ada1e1e8fc62",
  "extensions": []
}
"""

fileprivate let dgpJSON = """
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

fileprivate let extendedAccountJSON = """
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
  "validators_voted_for": 3,
  "validators_vote_weight": 42,
  "last_post": "1970-01-01T00:00:00",
  "last_root_post": "1970-01-01T00:00:00",
  "average_bandwidth": 0,
  "lifetime_bandwidth": 0,
  "last_bandwidth_update": "1970-01-01T00:00:00",
  "validator_votes": ["carol"],
  "valid": true,
  "account_seller": "",
  "account_offer_price": "0.000 VIZ",
  "account_on_sale": false,
  "subaccount_seller": "",
  "subaccount_offer_price": "0.000 VIZ",
  "subaccount_on_sale": false
}
"""
