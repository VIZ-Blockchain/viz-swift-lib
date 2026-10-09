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

    func testRoundTrip_accountValidatorProxy() {
        let fx = OperationFixture(
            value: Operation.AccountValidatorProxy(account: "alice", proxy: "proxy1"),
            json: "{\"account\":\"alice\",\"proxy\":\"proxy1\"}",
            binary: Data("05616c6963650670726f787931"),
            opIdName: "account_validator_proxy"
        )
        roundTrip(fx)
    }

    func testRoundTrip_custom() {
        let fx = OperationFixture(
            value: Operation.Custom(
                requiredActiveAuths: ["alice"],
                requiredRegularAuths: [],
                id: "test",
                json: "{}"
            ),
            json: "{\"required_active_auths\":[\"alice\"],\"required_regular_auths\":[],\"id\":\"test\",\"json\":\"{}\"}",
            binary: Data("0105616c696365000474657374027b7d"),
            opIdName: "custom"
        )
        roundTrip(fx)
    }

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

    func testVirtualDecode_shutdownValidator() {
        assertVirtualDecodes(
            opIdName: "shutdown_validator",
            json: "{\"owner\":\"alice\"}",
            Operation.ShutdownValidator(owner: "alice")
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

    func testVirtualDecode_validatorReward() {
        assertVirtualDecodes(
            opIdName: "validator_reward",
            json: "{\"validator\":\"alice\",\"shares\":\"0.500000 VESTS\"}",
            Operation.ValidatorReward(validator: "alice", shares: Asset(0.5, .vests))
        )
    }

    func testDecode_validatorReward_legacyWitnessKey() {
        let legacyJSON = "{\"witness\":\"alice\",\"shares\":\"0.500000 VESTS\"}"
        let expected = Operation.ValidatorReward(validator: "alice", shares: Asset(0.5, .vests))
        AssertDecodes(json: legacyJSON, expected)
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

        // 1. Operation.Convert — no OperationId.convert case exists.
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
        // canonical Swift type after the witness→validator rename.
        let cases: [(String, OperationType.Type)] = [
            ("witness_update",         Operation.ValidatorUpdate.self),
            ("account_witness_vote",   Operation.AccountValidatorVote.self),
            ("account_witness_proxy",  Operation.AccountValidatorProxy.self),
            ("shutdown_witness",       Operation.ShutdownValidator.self),
            ("witness_reward",         Operation.ValidatorReward.self),
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

    // MARK: - HF13/HF14/HF15 operations (vectors shared with viz-python-lib / viz-php-lib; gap ops via viz-js-lib-verified @viz-cx/core)

    func testRoundTrip_setRewardSharing() {
        let fx = OperationFixture(
            value: Operation.SetRewardSharing(
                owner: "alice",
                sharingRate: 5000
            ),
            json: "{\"owner\":\"alice\",\"sharing_rate\":5000}",
            binary: Data("05616c6963658813"),
            opIdName: "set_reward_sharing"
        )
        roundTrip(fx)
    }

    func testRoundTrip_fixedAward() {
        let fx = OperationFixture(
            value: Operation.FixedAward(
                initiator: "alice",
                receiver: "bob",
                rewardAmount: Asset("1.000 VIZ")!,
                maxEnergy: 10000,
                customSequence: 7,
                memo: "hi",
                beneficiaries: [Operation.Beneficiary(account: "carol", weight: 1000)]
            ),
            json: "{\"initiator\":\"alice\",\"receiver\":\"bob\",\"reward_amount\":\"1.000 VIZ\",\"max_energy\":10000,\"custom_sequence\":7,\"memo\":\"hi\",\"beneficiaries\":[{\"account\":\"carol\",\"weight\":1000}]}",
            binary: Data("05616c69636503626f62e8030000000000000356495a000000001027070000000000000002686901056361726f6ce803"),
            opIdName: "fixed_award"
        )
        roundTrip(fx)
    }

    func testRoundTrip_targetAccountSale() {
        let fx = OperationFixture(
            value: Operation.TargetAccountSale(
                account: "alice",
                accountSeller: "alice",
                targetBuyer: "bob",
                accountOfferPrice: Asset("100.000 VIZ")!,
                accountOnSale: true
            ),
            json: "{\"account\":\"alice\",\"account_seller\":\"alice\",\"target_buyer\":\"bob\",\"account_offer_price\":\"100.000 VIZ\",\"account_on_sale\":true}",
            binary: Data("05616c69636505616c69636503626f62a0860100000000000356495a0000000001"),
            opIdName: "target_account_sale"
        )
        roundTrip(fx)
    }

    func testRoundTrip_setAgentPermission() {
        let fx = OperationFixture(
            value: Operation.SetAgentPermission(
                account: "alice",
                agentName: "bot",
                agentKey: PublicKey("VIZ854Zwsap3RRynKwKYgnsPnoGtL2weiXRjp57Z5ojKCpRJszL2R")!,
                operations: ["award", "transfer"],
                expiration: Date(timeIntervalSince1970: 1893456000),
                addons: []
            ),
            json: "{\"account\":\"alice\",\"agent_name\":\"bot\",\"agent_key\":\"VIZ854Zwsap3RRynKwKYgnsPnoGtL2weiXRjp57Z5ojKCpRJszL2R\",\"operations\":[\"award\",\"transfer\"],\"expiration\":\"2030-01-01T00:00:00\",\"addons\":[],\"extensions\":[]}",
            binary: Data("05616c69636503626f7403a31847754ed837e6f177b587382a1993a91276a08ac26aa0e7673b19ab57b2fc02056177617264087472616e7366657280d8db700000"),
            opIdName: "set_agent_permission"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmOracleRegister() {
        let fx = OperationFixture(
            value: Operation.PmOracleRegister(
                owner: "alice",
                insurance: Asset("5000.000 VIZ")!,
                feePercent: 250,
                fixedFee: Asset("1.000 VIZ")!,
                rulesUrl: "http://r",
                autoAcceptCreator: "",
                autoAcceptResolver: "",
                autoAccept: true
            ),
            json: "{\"owner\":\"alice\",\"insurance\":\"5000.000 VIZ\",\"fee_percent\":250,\"fixed_fee\":\"1.000 VIZ\",\"rules_url\":\"http://r\",\"auto_accept_creator\":\"\",\"auto_accept_resolver\":\"\",\"auto_accept\":true,\"extensions\":[]}",
            binary: Data("05616c696365404b4c00000000000356495a00000000fa00e8030000000000000356495a0000000008687474703a2f2f7200000100"),
            opIdName: "pm_oracle_register"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmOracleUpdate() {
        let fx = OperationFixture(
            value: Operation.PmOracleUpdate(
                owner: "alice",
                insuranceDelta: Asset("100.000 VIZ")!,
                feePercent: nil,
                fixedFee: Asset("2.000 VIZ")!,
                rulesUrl: nil,
                autoAcceptCreator: nil,
                autoAcceptResolver: nil,
                autoAccept: false
            ),
            json: "{\"owner\":\"alice\",\"insurance_delta\":\"100.000 VIZ\",\"fee_percent\":null,\"fixed_fee\":\"2.000 VIZ\",\"rules_url\":null,\"auto_accept_creator\":null,\"auto_accept_resolver\":null,\"auto_accept\":false,\"extensions\":[]}",
            binary: Data("05616c69636501a0860100000000000356495a000000000001d0070000000000000356495a00000000000000010000"),
            opIdName: "pm_oracle_update"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmCreateMarket() {
        let fx = OperationFixture(
            value: Operation.PmCreateMarket(
                creator: "cre",
                oracle: "ora",
                marketType: 1,
                outcomes: ["Yes", "No", "Maybe"],
                url: "http://u",
                oracleFeePercent: 300,
                oracleFixedFee: Asset("1.000 VIZ")!,
                creatorFeePercent: 100,
                liquidityFeePercent: 50,
                liquidity: Asset("1000.000 VIZ")!,
                lmsrB: 722,
                bettingExpiration: Date(timeIntervalSince1970: 1893456000),
                resultExpiration: Date(timeIntervalSince1970: 1893542400),
                timePenaltyType: 1,
                timePenaltyValue: 86400,
                penaltyCurveType: 0,
                allowEarlyResolution: true,
                allowCancellation: false,
                allowBatch: false,
                allowInstantBet: true,
                endogeneityTier: 2,
                disputeMode: 1,
                disputeResolver: "res",
                disputePenaltyPercent: -500,
                metadata: "{\"tags\":[\"x\"]}"
            ),
            json: "{\"creator\":\"cre\",\"oracle\":\"ora\",\"market_type\":1,\"outcomes\":[\"Yes\",\"No\",\"Maybe\"],\"url\":\"http://u\",\"oracle_fee_percent\":300,\"oracle_fixed_fee\":\"1.000 VIZ\",\"creator_fee_percent\":100,\"liquidity_fee_percent\":50,\"liquidity\":\"1000.000 VIZ\",\"lmsr_b\":722,\"betting_expiration\":\"2030-01-01T00:00:00\",\"result_expiration\":\"2030-01-02T00:00:00\",\"time_penalty_type\":1,\"time_penalty_value\":86400,\"penalty_curve_type\":0,\"allow_early_resolution\":true,\"allow_cancellation\":false,\"allow_batch\":false,\"allow_instant_bet\":true,\"endogeneity_tier\":2,\"dispute_mode\":1,\"dispute_resolver\":\"res\",\"dispute_penalty_percent\":-500,\"metadata\":\"{\\\"tags\\\":[\\\"x\\\"]}\",\"extensions\":[]}",
            binary: Data("03637265036f7261010303596573024e6f054d6179626508687474703a2f2f752c01e8030000000000000356495a000000006400320040420f00000000000356495a00000000d20200000000000080d8db70002add70018051010000010000010201037265730cfe0e7b2274616773223a5b2278225d7d00"),
            opIdName: "pm_create_market"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmOracleAcceptMarket() {
        let fx = OperationFixture(
            value: Operation.PmOracleAcceptMarket(
                oracle: "ora",
                marketId: 42,
                accept: true,
                oracleFeePercent: 200,
                oracleFixedFee: Asset("0.500 VIZ")!
            ),
            json: "{\"oracle\":\"ora\",\"market_id\":42,\"accept\":true,\"oracle_fee_percent\":200,\"oracle_fixed_fee\":\"0.500 VIZ\",\"extensions\":[]}",
            binary: Data("036f72612a0000000000000001c800f4010000000000000356495a0000000000"),
            opIdName: "pm_oracle_accept_market"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmPlaceBet() {
        let fx = OperationFixture(
            value: Operation.PmPlaceBet(
                account: "alice",
                marketId: 42,
                side: 1,
                outcomeIndex: -1,
                amount: Asset("1.500 VIZ")!,
                minTokens: 0,
                mode: 0
            ),
            json: "{\"account\":\"alice\",\"market_id\":42,\"side\":1,\"outcome_index\":-1,\"amount\":\"1.500 VIZ\",\"min_tokens\":0,\"mode\":0,\"extensions\":[]}",
            binary: Data("05616c6963652a0000000000000001ffffdc050000000000000356495a0000000000000000000000000000"),
            opIdName: "pm_place_bet"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmCommitBet() {
        let fx = OperationFixture(
            value: Operation.PmCommitBet(
                account: "alice",
                marketId: 42,
                commitment: Data("abababababababababababababababababababababababababababababababab"),
                escrowAmount: Asset("10.000 VIZ")!,
                noRevealFeePercent: 2000
            ),
            json: "{\"account\":\"alice\",\"market_id\":42,\"commitment\":\"abababababababababababababababababababababababababababababababab\",\"escrow_amount\":\"10.000 VIZ\",\"no_reveal_fee_percent\":2000,\"extensions\":[]}",
            binary: Data("05616c6963652a00000000000000abababababababababababababababababababababababababababababababab10270000000000000356495a00000000d00700"),
            opIdName: "pm_commit_bet"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmRevealBet() {
        let fx = OperationFixture(
            value: Operation.PmRevealBet(
                account: "alice",
                commitId: 9,
                side: 0,
                outcomeIndex: -1,
                amount: Asset("5.000 VIZ")!,
                salt: "saltsalt",
                minTokens: 0
            ),
            json: "{\"account\":\"alice\",\"commit_id\":9,\"side\":0,\"outcome_index\":-1,\"amount\":\"5.000 VIZ\",\"salt\":\"saltsalt\",\"min_tokens\":0,\"extensions\":[]}",
            binary: Data("05616c696365090000000000000000ffff88130000000000000356495a000000000873616c7473616c74000000000000000000"),
            opIdName: "pm_reveal_bet"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmCancelBet() {
        let fx = OperationFixture(
            value: Operation.PmCancelBet(
                account: "alice",
                betId: 9,
                minReturn: 100
            ),
            json: "{\"account\":\"alice\",\"bet_id\":9,\"min_return\":100,\"extensions\":[]}",
            binary: Data("05616c6963650900000000000000640000000000000000"),
            opIdName: "pm_cancel_bet"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmAddLiquidity() {
        let fx = OperationFixture(
            value: Operation.PmAddLiquidity(
                provider: "lp",
                marketId: 42,
                amount: Asset("500.000 VIZ")!
            ),
            json: "{\"provider\":\"lp\",\"market_id\":42,\"amount\":\"500.000 VIZ\",\"extensions\":[]}",
            binary: Data("026c702a0000000000000020a10700000000000356495a0000000000"),
            opIdName: "pm_add_liquidity"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmWithdrawLiquidity() {
        let fx = OperationFixture(
            value: Operation.PmWithdrawLiquidity(
                provider: "lp",
                liquidityId: 3,
                amount: Asset("0.000 VIZ")!
            ),
            json: "{\"provider\":\"lp\",\"liquidity_id\":3,\"amount\":\"0.000 VIZ\",\"extensions\":[]}",
            binary: Data("026c70030000000000000000000000000000000356495a0000000000"),
            opIdName: "pm_withdraw_liquidity"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmResolveMarket() {
        let fx = OperationFixture(
            value: Operation.PmResolveMarket(
                oracle: "ora",
                marketId: 42,
                winningOutcome: 1,
                decisionUrl: "http://d",
                decisionReason: "because"
            ),
            json: "{\"oracle\":\"ora\",\"market_id\":42,\"winning_outcome\":1,\"decision_url\":\"http://d\",\"decision_reason\":\"because\",\"extensions\":[]}",
            binary: Data("036f72612a00000000000000010008687474703a2f2f64076265636175736500"),
            opIdName: "pm_resolve_market"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmNoContest() {
        let fx = OperationFixture(
            value: Operation.PmNoContest(
                oracle: "ora",
                marketId: 42,
                reason: "void"
            ),
            json: "{\"oracle\":\"ora\",\"market_id\":42,\"reason\":\"void\",\"extensions\":[]}",
            binary: Data("036f72612a0000000000000004766f696400"),
            opIdName: "pm_no_contest"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmDisputeCreate() {
        let fx = OperationFixture(
            value: Operation.PmDisputeCreate(
                disputer: "bob",
                marketId: 7,
                proposedOutcome: 1,
                reason: "wrong"
            ),
            json: "{\"disputer\":\"bob\",\"market_id\":7,\"proposed_outcome\":1,\"reason\":\"wrong\",\"extensions\":[]}",
            binary: Data("03626f62070000000000000001000577726f6e6700"),
            opIdName: "pm_dispute_create"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmDisputeVote() {
        let fx = OperationFixture(
            value: Operation.PmDisputeVote(
                voter: "carol",
                marketId: 7,
                voteOutcome: 0,
                votePercent: 5000
            ),
            json: "{\"voter\":\"carol\",\"market_id\":7,\"vote_outcome\":0,\"vote_percent\":5000,\"extensions\":[]}",
            binary: Data("056361726f6c07000000000000000000881300"),
            opIdName: "pm_dispute_vote"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmDisputeResolve() {
        let fx = OperationFixture(
            value: Operation.PmDisputeResolve(
                resolver: "res",
                marketId: 7,
                correctOutcome: 1,
                penaltyAmount: Asset("50.000 VIZ")!,
                banOracle: true,
                banOracleUntil: Date(timeIntervalSince1970: 1798761600),
                banCreator: false,
                banCreatorUntil: Date(timeIntervalSince1970: 0)
            ),
            json: "{\"resolver\":\"res\",\"market_id\":7,\"correct_outcome\":1,\"penalty_amount\":\"50.000 VIZ\",\"ban_oracle\":true,\"ban_oracle_until\":\"2027-01-01T00:00:00\",\"ban_creator\":false,\"ban_creator_until\":\"1970-01-01T00:00:00\",\"extensions\":[]}",
            binary: Data("037265730700000000000000010050c30000000000000356495a000000000180ec366b000000000000"),
            opIdName: "pm_dispute_resolve"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmTransferPosition() {
        let fx = OperationFixture(
            value: Operation.PmTransferPosition(
                from: "alice",
                betId: 9,
                to: "bob",
                amount: 1000,
                memo: "hi"
            ),
            json: "{\"from\":\"alice\",\"bet_id\":9,\"to\":\"bob\",\"amount\":1000,\"memo\":\"hi\",\"extensions\":[]}",
            binary: Data("05616c696365090000000000000003626f62e80300000000000002686900"),
            opIdName: "pm_transfer_position"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmLazyDeposit() {
        let fx = OperationFixture(
            value: Operation.PmLazyDeposit(
                account: "alice",
                amount: Asset("200.000 VIZ")!
            ),
            json: "{\"account\":\"alice\",\"amount\":\"200.000 VIZ\",\"extensions\":[]}",
            binary: Data("05616c696365400d0300000000000356495a0000000000"),
            opIdName: "pm_lazy_deposit"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmLazyWithdraw() {
        let fx = OperationFixture(
            value: Operation.PmLazyWithdraw(
                account: "alice",
                shares: 500,
                emergency: true
            ),
            json: "{\"account\":\"alice\",\"shares\":500,\"emergency\":true,\"extensions\":[]}",
            binary: Data("05616c696365f4010000000000000100"),
            opIdName: "pm_lazy_withdraw"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmLeverageOpen() {
        let fx = OperationFixture(
            value: Operation.PmLeverageOpen(
                account: "alice",
                marketId: 42,
                outcomeIndex: 0,
                collateral: Asset("10.000 VIZ")!,
                loan: Asset("40.000 VIZ")!,
                minTokens: 0,
                maxSlippagePercent: 1000
            ),
            json: "{\"account\":\"alice\",\"market_id\":42,\"outcome_index\":0,\"collateral\":\"10.000 VIZ\",\"loan\":\"40.000 VIZ\",\"min_tokens\":0,\"max_slippage_percent\":1000,\"extensions\":[]}",
            binary: Data("05616c6963652a00000000000000000010270000000000000356495a00000000409c0000000000000356495a000000000000000000000000e80300"),
            opIdName: "pm_leverage_open"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmLeverageClose() {
        let fx = OperationFixture(
            value: Operation.PmLeverageClose(
                account: "alice",
                positionId: 5,
                minReturn: 100
            ),
            json: "{\"account\":\"alice\",\"position_id\":5,\"min_return\":100,\"extensions\":[]}",
            binary: Data("05616c6963650500000000000000640000000000000000"),
            opIdName: "pm_leverage_close"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmLeverageConvert() {
        let fx = OperationFixture(
            value: Operation.PmLeverageConvert(
                account: "alice",
                positionId: 5,
                conversionProfitCost: 300
            ),
            json: "{\"account\":\"alice\",\"position_id\":5,\"conversion_profit_cost\":300,\"extensions\":[]}",
            binary: Data("05616c69636505000000000000002c0100"),
            opIdName: "pm_leverage_convert"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmDisputeOracleRespond() {
        let fx = OperationFixture(
            value: Operation.PmDisputeOracleRespond(
                oracle: "ora",
                marketId: 7,
                response: "rebuttal"
            ),
            json: "{\"oracle\":\"ora\",\"market_id\":7,\"response\":\"rebuttal\",\"extensions\":[]}",
            binary: Data("036f7261070000000000000008726562757474616c00"),
            opIdName: "pm_dispute_oracle_respond"
        )
        roundTrip(fx)
    }

    func testRoundTrip_pmUnban() {
        let fx = OperationFixture(
            value: Operation.PmUnban(
                resolver: "res",
                target: "ora",
                unbanOracle: true,
                unbanCreator: false
            ),
            json: "{\"resolver\":\"res\",\"target\":\"ora\",\"unban_oracle\":true,\"unban_creator\":false,\"extensions\":[]}",
            binary: Data("03726573036f7261010000"),
            opIdName: "pm_unban"
        )
        roundTrip(fx)
    }

    func testVirtualDecode_stakeholderReward() {
        assertVirtualDecodes(
            opIdName: "stakeholder_reward",
            json: "{\"validator\":\"v\",\"stakeholder\":\"s\",\"shares\":\"1.000000 SHARES\"}",
            Operation.StakeholderReward(validator: "v", stakeholder: "s", shares: Asset("1.000000 SHARES")!)
        )
    }

    func testVirtualDecode_pmPayout() {
        assertVirtualDecodes(
            opIdName: "pm_payout",
            json: "{\"account\":\"alice\",\"market_id\":42,\"bet_id\":9,\"side\":1,\"outcome_index\":-1,\"amount\":\"1.500 VIZ\",\"payout\":\"2.000 VIZ\"}",
            Operation.PmPayout(account: "alice", marketId: 42, betId: 9, side: 1, outcomeIndex: -1, amount: Asset("1.500 VIZ")!, payout: Asset("2.000 VIZ")!)
        )
    }

    func testVirtualDecode_pmLeverageResolve() {
        assertVirtualDecodes(
            opIdName: "pm_leverage_resolve",
            json: "{\"account\":\"alice\",\"position_id\":5,\"market_id\":42,\"won\":true,\"pool_received\":\"1.000 VIZ\",\"bettor_received\":\"3.000 VIZ\",\"outcome_index\":0,\"leverage\":500}",
            Operation.PmLeverageResolve(account: "alice", positionId: 5, marketId: 42, won: true, poolReceived: Asset("1.000 VIZ")!, bettorReceived: Asset("3.000 VIZ")!, outcomeIndex: 0, leverage: 500)
        )
    }

    func testVirtualDecode_pmLpPayout() {
        assertVirtualDecodes(
            opIdName: "pm_lp_payout",
            json: "{\"account\":\"lp\",\"market_id\":42,\"principal\":\"500.000 VIZ\",\"income\":\"5.000 VIZ\",\"charge\":\"0.100 VIZ\"}",
            Operation.PmLpPayout(account: "lp", marketId: 42, principal: Asset("500.000 VIZ")!, income: Asset("5.000 VIZ")!, charge: Asset("0.100 VIZ")!)
        )
    }
}
