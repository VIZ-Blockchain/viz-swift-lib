@testable import VIZ
import XCTest

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
}
