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

    func testBroadcastAward() {
        let test = expectation(description: "Response")
        let key = PrivateKey("5K5exRbTT5d6HnAsNgdFptedttd8w9HnYXz3jfmPbK35GZQXqia")!
        let award = Operation.Award(initiator: "babin", receiver: "babin", energy: 1, customSequence: 0, memo: "", beneficiaries: [])
        client.send(API.GetDynamicGlobalProperties()) { props, error in
            XCTAssertNil(error)
            guard let props = props else {
                return XCTFail("Unable to get props")
            }
            let expiry = props.time.addingTimeInterval(60)
            let tx = Transaction(
                refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
                refBlockPrefix: props.headBlockId.prefix,
                expiration: expiry,
                operations: [award]
            )

            guard let stx = try? tx.sign(usingKey: key) else {
                return XCTFail("Unable to sign tx")
            }
            let trx = API.BroadcastTransaction(transaction: stx)
            client.send(trx) { res, error in
                XCTAssertNil(error)
                if let res = res {
                    XCTAssertFalse(res.expired)
                    XCTAssert(res.blockNum > props.headBlockId.num)
                } else {
                    XCTFail("No response")
                }
                test.fulfill()
            }
        }
        waitForExpectations(timeout: 10) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func testAccountUpdate() {
        let test = expectation(description: "Response")
        let accountName = "microb"
        let password = "some random generated string"

        let masterKey = PrivateKey(seed: accountName + "master" + password)!
        let masterPublicKey = masterKey.createPublic()
        let masterAuthority = Authority(keyAuths: [Authority.Auth(masterPublicKey)])

        let activeKey = PrivateKey(seed: accountName + "active" + password)
        let activePublicKey = activeKey!.createPublic()
        let activeAuthority = Authority(keyAuths: [Authority.Auth(activePublicKey)])

        let regularKey = PrivateKey(seed: accountName + "regular" + password)
        let regularPublicKey = regularKey!.createPublic()
        let regularAuthority = Authority(keyAuths: [Authority.Auth(regularPublicKey)])

        let memoPublicKey = PrivateKey(seed: accountName + "memo" + password)!.createPublic()

        let accountUpdate = VIZ.Operation.AccountUpdate(account: accountName, master: masterAuthority, active: activeAuthority, regular: regularAuthority, memoKey: memoPublicKey)
        client.send(API.GetDynamicGlobalProperties()) { props, error in
            XCTAssertNil(error)
            guard let props = props else {
                return XCTFail("Unable to get props")
            }
            let expiry = props.time.addingTimeInterval(60)
            let tx = Transaction(
                refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
                refBlockPrefix: props.headBlockId.prefix,
                expiration: expiry,
                operations: [accountUpdate]
            )

            guard let stx = try? tx.sign(usingKey: masterKey) else {
                return XCTFail("Unable to sign tx")
            }
            let trx = API.BroadcastTransaction(transaction: stx)
            client.send(trx) { res, error in
                if error.debugDescription.contains("CHAIN_MASTER_UPDATE_LIMIT") {} else {
                    XCTAssertNil(error)
                    if let res = res {
                        XCTAssertFalse(res.expired)
                        XCTAssert(res.blockNum > props.headBlockId.num)
                    } else {
                        XCTFail("No response")
                    }
                }
                test.fulfill()
            }
        }
        waitForExpectations(timeout: 10) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

//    func testInviteRegistration() {
//        let test = expectation(description: "Response")
//        let inviteAccountActive = PrivateKey("5KcfoRuDfkhrLCxVcE9x51J6KN9aM9fpb78tLrvvFckxVV6FyFW")!
//        let inviteRegistration = VIZ.Operation.InviteRegistration(
//            initiator: "invite",
//            newAccountName: "tester",
//            inviteSecret: "5KVvGJo9HGXoYBFiLbNqckJR8YxrRKApFjmL3PYWQeUNuaRZhXe",
//            newAccountKey: inviteAccountActive.createPublic()
//        )
//        client.send(API.GetDynamicGlobalProperties()) { props, error in
//            XCTAssertNil(error)
//            guard let props = props else {
//                return XCTFail("Unable to get props")
//            }
//            let expiry = props.time.addingTimeInterval(60)
//            let tx = Transaction(
//                refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
//                refBlockPrefix: props.headBlockId.prefix,
//                expiration: expiry,
//                operations: [inviteRegistration]
//            )
//            guard let stx = try? tx.sign(usingKey: inviteAccountActive) else {
//                return XCTFail("Unable to sign tx")
//            }
//            let trx = API.BroadcastTransaction(transaction: stx)
//            client.send(trx) { res, error in
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
        let req = API.GetAccountHistory(account: "sinteaspirans", from: -1, limit: 1)
        let result = try client.sendSynchronous(req)
        guard result != nil else {
            XCTFail("No results returned")
            return
        }
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
        let req = API.GetAccountHistory(account: "id", from: -1, limit: 1)
        let result = try client.sendSynchronous(req)
        guard result != nil else {
            XCTFail("No results returned")
            return
        }
    }
}
