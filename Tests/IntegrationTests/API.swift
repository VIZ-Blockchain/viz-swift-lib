@testable import VIZ
import XCTest

let client = VIZ.Client(address: URL(string: "https://node.viz.cx")!)

// https://github.com/VIZ-Blockchain/viz-cpp-node/blob/master/share/vizd/snapshot-testnet.json
//let testnetClient = VIZ.Client(address: URL(string: "https://testnet.viz.cx")!)
//let testnetId = ChainId.custom(Data(hexEncoded: "46d82ab7d8db682eb1959aed0ada039a6d49afa1602491f93dde9cac3e8e6c32"))

class ClientTest: XCTestCase {
    func testNani() {
        debugPrint(Data(hexEncoded: "79276aea5d4877d9a25892eaa01b0adf019d3e5cb12a97478df3298ccdd01673").base64EncodedString())
    }

    func testGlobalProps() {
        let test = expectation(description: "Response")
        let req = API.GetDynamicGlobalProperties()
        client.send(req) { res, error in
            XCTAssertNil(error)
            XCTAssertNotNil(res)
            XCTAssertEqual(res?.currentSupply.symbol.name, "VIZ")
            test.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func testGetBlock() {
        let test = expectation(description: "Response")
        let req = API.GetBlock(blockNum: 25_199_247)
        client.send(req) { block, error in
            XCTAssertNil(error)
            XCTAssertEqual(block?.previous.num, 25_199_246)
            XCTAssertEqual(block?.transactions.count, 2)
            test.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

//    func testBroadcast() {
//        let test = expectation(description: "Response")
//        let key = PrivateKey("5KS8eoAGLrCg2w3ytqSQXsmHuDTdvb2NLjJLpxgaiVJDXaGpcGT")!
//        var comment = Operation.Comment(
//            title: "Hello from Swift",
//            body: "The time is \(Date()) and I'm running tests.",
//            author: "test19",
//            permlink: "hey-eveyone-im-running-swift-tests-and-the-time-is-\(UInt32(Date().timeIntervalSinceReferenceDate))"
//        )
//        comment.parentPermlink = "test"
//        let vote = Operation.Vote(voter: "test19", author: "test19", permlink: comment.permlink)
//        testnetClient.send(API.GetDynamicGlobalProperties()) { props, error in
//            XCTAssertNil(error)
//            guard let props = props else {
//                return XCTFail("Unable to get props")
//            }
//            let expiry = props.time.addingTimeInterval(60)
//            let tx = Transaction(
//                refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
//                refBlockPrefix: props.headBlockId.prefix,
//                expiration: expiry,
//                operations: [comment, vote]
//            )
//
//            guard let stx = try? tx.sign(usingKey: key, forChain: testnetId) else {
//                return XCTFail("Unable to sign tx")
//            }
//            testnetClient.send(API.BroadcastTransaction(transaction: stx)) { res, error in
//                XCTAssertNil(error)
//                if let res = res {
//                    XCTAssertFalse(res.expired)
//                    XCTAssert(res.blockNum > props.headBlockId.num)
//                } else {
//                    XCTFail("No response")
//                }
//                test.fulfill()
//            }
//        }
//        waitForExpectations(timeout: 10) { error in
//            if let error = error {
//                print("Error: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    func testTransferBroadcast() {
//        let test = expectation(description: "Response")
//        let key = PrivateKey("5KS8eoAGLrCg2w3ytqSQXsmHuDTdvb2NLjJLpxgaiVJDXaGpcGT")!
//
//
//
//        let transfer = Operation.Transfer.init(from: "test19", to: "maitland", amount: Asset(1, .custom(name: "TESTS", precision: 3)), memo: "Gulliver's travels.")
//
//        testnetClient.send(API.GetDynamicGlobalProperties()) { props, error in
//            XCTAssertNil(error)
//            guard let props = props else {
//                return XCTFail("Unable to get props")
//            }
//            let expiry = props.time.addingTimeInterval(60)
//
//            let tx = Transaction(
//                refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
//                refBlockPrefix: props.headBlockId.prefix,
//                expiration: expiry,
//                operations: [transfer]
//            )
//
//            guard let stx = try? tx.sign(usingKey: key, forChain: testnetId) else {
//                return XCTFail("Unable to sign tx")
//            }
//            testnetClient.send(API.BroadcastTransaction(transaction: stx)) { res, error in
//                XCTAssertNil(error)
//                if let res = res {
//                    XCTAssertFalse(res.expired)
//                    XCTAssert(res.blockNum > props.headBlockId.num)
//                } else {
//                    XCTFail("No response")
//                }
//                test.fulfill()
//            }
//        }
//        waitForExpectations(timeout: 10) { error in
//            if let error = error {
//                print("Error: \(error.localizedDescription)")
//            }
//        }
//    }

    func testGetAccount() throws {
        let result = try client.sendSynchronous(API.GetAccounts(names: ["kelechek"]))
        guard let account = result?.first else {
            XCTFail("No account returned")
            return
        }
        XCTAssertEqual(account.id, 3775)
        XCTAssertEqual(account.name, "kelechek")
        XCTAssertEqual(account.created, Date(timeIntervalSince1970: 1577304837))
    }
    
//    func testTestnetGetAccount() throws {
//        let result = try testnetClient.sendSynchronous(API.GetAccounts(names: ["id"]))
//        guard let account = result?.first else {
//            XCTFail("No account returned")
//            return
//        }
//
//        XCTAssertEqual(account.id, 40413)
//        XCTAssertEqual(account.name, "id")
//    }

    func testGetAccountHistory() throws {
        let req = API.GetAccountHistory(account: "sinteaspirans", from: 1, limit: 1)
        let result = try client.sendSynchronous(req)
        guard let r = result?.first else {
            XCTFail("No results returned")
            return
        }
        let createOp = r.value.operation as? VIZ.Operation.AccountCreate
        XCTAssertEqual(createOp?.newAccountName, "sinteaspirans")
    }
    
//    func testTestnetGetAccountHistory() throws {
//        let req = API.GetAccountHistory(account: "id", from: 1, limit: 1)
//        let result = try testnetClient.sendSynchronous(req)
//        guard let r = result?.first else {
//            XCTFail("No results returned")
//            return
//        }
//        let createOp = r.value.operation as? VIZ.Operation.AccountCreate
//        XCTAssertEqual(createOp?.newAccountName, "id")
//    }

    func testGetAccountHistoryVirtual() throws {
        let req = API.GetAccountHistory(account: "id", from: 100, limit: 0)
        let result = try client.sendSynchronous(req)
        guard let r = result?.first else {
            XCTFail("No results returned")
            return
        }
        let op = r.value.operation as? VIZ.Operation.Award
        XCTAssertEqual(op?.isVirtual, false)
        XCTAssertEqual(op?.initiator, "id")
        XCTAssertEqual(op?.receiver, "investing")
        XCTAssertEqual(op?.energy, 5)
        XCTAssertEqual(op?.customSequence, 0)
        XCTAssertEqual(op?.memo, "")
    }
}
