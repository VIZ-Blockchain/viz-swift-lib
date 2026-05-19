@testable import VIZ
import XCTest

fileprivate struct OperationFixture<Op: OperationType & Equatable & Decodable> {
    let value: Op
    let json: String        // canonical snake_case JSON of the operation body
    let binary: Data        // canonical binary hex of the operation body (no OperationId prefix)
    let opIdName: String    // string form of the op id, e.g. "vote", used for AnyOperation wrapping
}

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

fileprivate let vote = (
    Operation.Vote(voter: "foo", author: "bar", permlink: "baz", weight: 1000),
    "{\"voter\":\"foo\",\"author\":\"bar\",\"permlink\":\"baz\",\"weight\":1000}"
)

fileprivate let transfer = (
    Operation.Transfer(from: "foo", to: "bar", amount: Asset(10, .viz), memo: "baz"),
    "{\"from\":\"foo\",\"to\":\"bar\",\"amount\":\"10.000 VIZ\",\"memo\":\"baz\"}"
)

fileprivate let commentOptions = (
    Operation.CommentOptions(author: "foo", permlink: "bar", maxAcceptedPayout: Asset(10, .viz), percentSteemDollars: 41840, allowVotes: true, allowCurationRewards: true, extensions: [.commentPayoutBeneficiaries([Operation.CommentOptions.BeneficiaryRoute(account: "baz", weight: 5000)])]),
    "{\"author\":\"foo\",\"permlink\":\"bar\",\"max_accepted_payout\":\"10.000 VIZ\",\"percent_steem_dollars\":41840,\"allow_votes\":true,\"allow_curation_rewards\":true,\"extensions\":[[0,{\"beneficiaries\":[{\"account\":\"baz\",\"weight\":5000}]}]]}"
)

let account_create = (
    Operation.AccountCreate(
        fee: Asset("10.000 VIZ")!,
        creator: "viz",
        newAccountName: "paulsphotography",
        master: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!: 1]]),
        active: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6")!: 1]]),
        regular: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ5oPsxWgfCH2FWqcXBWeeMmZoyBY5baiuV1vQWMxVVpYxEsJ6Hx")!: 1]]),
        memoKey: PublicKey("VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH")!,
        jsonMetadata: ""
    ),
    "{\"fee\":\"10.000 VIZ\",\"creator\":\"viz\",\"new_account_name\":\"paulsphotography\",\"master\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau\",1]]},\"active\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6\",1]]},\"regular\":{\"weight_threshold\":1,\"account_auths\":[],\"key_auths\":[[\"VIZ5oPsxWgfCH2FWqcXBWeeMmZoyBY5baiuV1vQWMxVVpYxEsJ6Hx\",1]]},\"memo_key\":\"VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH\",\"json_metadata\":\"\"}",
    Data("10270000000000000356495a000000000376697a107061756c7370686f746f67726170687901000000000103c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b0100010000000001021b49b04b2406912fbd4a183512b3cdf72c215eba13ceb0c9700db4fbef1dc2570100010000000001027820f0c756d3bc57ce05547fe828d20e03b7fc74e8e4968f984e38b3e26449cb0100034ff417d40dae1849b2187ebd4514b8068db851b73bee6f4c7903e7c8677059ef00")
)

class OperationTest: XCTestCase {
    func testEncodable() throws {
        AssertEncodes(vote.0, Data("03666f6f036261720362617ae803"))
        AssertEncodes(vote.0, ["voter": "foo", "author": "bar", "permlink": "baz"])
        AssertEncodes(vote.0, ["weight": 1000])
        AssertEncodes(transfer.0, Data("03666f6f0362617210270000000000000356495a000000000362617a"))
        AssertEncodes(transfer.0, ["from": "foo", "to": "bar", "amount": "10.000 VIZ", "memo": "baz"])
        AssertEncodes(commentOptions.0, Data("03666f6f0362617210270000000000000356495a0000000070a301010100010362617a8813"))
        AssertEncodes(account_create.0, account_create.2)
    }

    func testDecodable() {
        AssertDecodes(json: vote.1, vote.0)
        AssertDecodes(json: transfer.1, transfer.0)
        AssertDecodes(json: commentOptions.1, commentOptions.0)
        AssertDecodes(json: account_create.1, account_create.0)
        XCTAssert(vote.0.isVirtual == false)
    }

    func testVirtual() {
        let opJson = "{\"curator\":\"foo\",\"reward\":\"0.010366 VESTS\",\"comment_author\":\"foo\",\"comment_permlink\":\"foo\"}"
        let op = Operation.CurationReward(curator: "foo", reward: Asset(0.010366, .vests), commentAuthor: "foo", commentPermlink: "foo")
        AssertDecodes(json: opJson, op)
        XCTAssert(op.isVirtual)
    }

    func testRoundTrip_vote() {
        let fx = OperationFixture(
            value: Operation.Vote(voter: "foo", author: "bar", permlink: "baz", weight: 1000),
            json: "{\"voter\":\"foo\",\"author\":\"bar\",\"permlink\":\"baz\",\"weight\":1000}",
            binary: Data("03666f6f036261720362617ae803"),
            opIdName: "vote"
        )
        roundTrip(fx)
    }

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
            binary: Data("000b72752d2d67656e6572616c05616c6963650b68656c6c6f2d776f726c640548656c6c6f05576f726c64027b7d"),
            opIdName: "content"
        )
        roundTrip(fx)
    }

    func testRoundTrip_transfer() {
        let fx = OperationFixture(
            value: Operation.Transfer(from: "foo", to: "bar", amount: Asset(10, .viz), memo: "baz"),
            json: "{\"from\":\"foo\",\"to\":\"bar\",\"amount\":\"10.000 VIZ\",\"memo\":\"baz\"}",
            binary: Data("03666f6f0362617210270000000000000356495a000000000362617a"),
            opIdName: "transfer"
        )
        roundTrip(fx)
    }

    func testRoundTrip_transferToVesting() {
        let fx = OperationFixture(
            value: Operation.TransferToVesting(from: "alice", to: "bob", amount: Asset(5, .viz)),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"amount\":\"5.000 VIZ\"}",
            binary: Data("05616c69636503626f6288130000000000000356495a00000000"),
            opIdName: "transfer_to_vesting"
        )
        roundTrip(fx)
    }

    func testRoundTrip_withdrawVesting() {
        let fx = OperationFixture(
            value: Operation.WithdrawVesting(account: "alice", vestingShares: Asset(100, .vests)),
            json: "{\"account\":\"alice\",\"vesting_shares\":\"100.000000 VESTS\"}",
            binary: Data("05616c69636500e1f505000000000656455354530000"),
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
            binary: Data("10270000000000000356495a000000000376697a066e657762696501000000000103c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b0100010000000001021b49b04b2406912fbd4a183512b3cdf72c215eba13ceb0c9700db4fbef1dc2570100010000000001027820f0c756d3bc57ce05547fe828d20e03b7fc74e8e4968f984e38b3e26449cb0100034ff417d40dae1849b2187ebd4514b8068db851b73bee6f4c7903e7c8677059ef00"),
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
            binary: Data("05616c6963650101000000000103c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b01000000034ff417d40dae1849b2187ebd4514b8068db851b73bee6f4c7903e7c8677059ef00"),
            opIdName: "account_update"
        )
        roundTrip(fx)
    }

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

    func testRoundTrip_accountWitnessProxy() {
        let fx = OperationFixture(
            value: Operation.AccountWitnessProxy(account: "alice", proxy: "proxy1"),
            json: "{\"account\":\"alice\",\"proxy\":\"proxy1\"}",
            binary: Data("05616c6963650670726f787931"),
            opIdName: "account_witness_proxy"
        )
        roundTrip(fx)
    }

    // testRoundTrip_custom is omitted: AnyOperation.encode dispatches on Operation.Custom
    // but AnyOperation.init(from:) decodes the "custom" op_id as Operation.CustomJson.
    // The two types are incompatible, so the AnyOperation round-trip step always fails.
    // Tracked as a Task 6 encode/decode asymmetry.

    // testRoundTrip_deleteContent is omitted: "delete_content" is absent from the
    // string-switch in OperationId.init(from:), so the AnyOperation round-trip
    // step decodes to Operation.Unknown instead of Operation.DeleteContent.
    // Tracked as a Task 6 encode/decode asymmetry.

    func testRoundTrip_setWithdrawVestingRoute() {
        let fx = OperationFixture(
            value: Operation.SetWithdrawVestingRoute(fromAccount: "alice", toAccount: "bob", percent: 5000, autoVest: false),
            json: "{\"from_account\":\"alice\",\"to_account\":\"bob\",\"percent\":5000,\"auto_vest\":false}",
            binary: Data("05616c69636503626f62881300"),
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
            binary: Data("0376697a05616c69636501000000000103c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b010000"),
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
            binary: Data("05616c69636501000000000103c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b0100010000000001021b49b04b2406912fbd4a183512b3cdf72c215eba13ceb0c9700db4fbef1dc257010000"),
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
            binary: Data("05616c6963650376697a00"),
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
            binary: Data("05616c69636503626f62056361726f6c0100000000000000000000000356495a0000000088130000000000000356495a0000000064000000000000000356495a0000000000f153658042556500"),
            opIdName: "escrow_transfer"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowDispute() {
        let fx = OperationFixture(
            value: Operation.EscrowDispute(from: "alice", to: "bob", agent: "carol", who: "alice", escrowId: 1),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"who\":\"alice\",\"escrow_id\":1}",
            binary: Data("05616c69636503626f62056361726f6c05616c69636501000000"),
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
            binary: Data("05616c69636503626f62056361726f6c056361726f6c03626f620100000000000000000000000356495a0000000088130000000000000356495a00000000"),
            opIdName: "escrow_release"
        )
        roundTrip(fx)
    }

    func testRoundTrip_escrowApprove() {
        let fx = OperationFixture(
            value: Operation.EscrowApprove(from: "alice", to: "bob", agent: "carol", who: "carol", escrowId: 1, approve: true),
            json: "{\"from\":\"alice\",\"to\":\"bob\",\"agent\":\"carol\",\"who\":\"carol\",\"escrow_id\":1,\"approve\":true}",
            binary: Data("05616c69636503626f62056361726f6c056361726f6c0100000001"),
            opIdName: "escrow_approve"
        )
        roundTrip(fx)
    }

    func testRoundTrip_delegateVestingShares() {
        let fx = OperationFixture(
            value: Operation.DelegateVestingShares(delegator: "alice", delegatee: "bob", vestingShares: Asset(1000, .vests)),
            json: "{\"delegator\":\"alice\",\"delegatee\":\"bob\",\"vesting_shares\":\"1000.000000 VESTS\"}",
            binary: Data("05616c69636503626f6200ca9a3b000000000656455354530000"),
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
            binary: Data("05616c69636503626f6264000000000000000000067468616e6b7301056361726f6ce803"),
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
            binary: Data("05616c69636503626f620000000000000000067468616e6b7320a10700000000000656455354530000"),
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
            binary: Data("05616c69636503626f62056361726f6c0000000000000000067468616e6b7320a10700000000000656455354530000"),
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
            binary: Data("06696e7669746505616c69636533354b5676474a6f394847586f594246694c624e71636b4a5238597872524b4170466a6d4c335059575165554e7561525a68586503c5ce92a15f7120ae896f348c4ce505d9573cf0816338a478dd9845fe7b1ec59b"),
            opIdName: "invite_registration"
        )
        roundTrip(fx)
    }

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
        // "content_reward" is not in OperationId.init(from:)'s string-switch — AnyOperation decodes
        // it as Operation.Unknown. Verify the struct decodes from a bare body JSON instead.
        AssertDecodes(
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
                guard any.operation as? VIZ.Operation.Unknown != nil else {
                    XCTFail("Expected \(opIdName) to decode as Operation.Unknown, got \(type(of: any.operation))")
                    continue
                }
            } catch {
                XCTFail("Decode of \(opIdName) failed: \(error)")
            }
        }
    }

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

        // ReportOverProduction: skipped — BlockId has no public initializer; covered by encode-dispatch switch's lack of a case.
    }

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
}
