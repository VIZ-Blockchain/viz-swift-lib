@testable import VIZ
import XCTest

fileprivate let client = VIZ.Client(address: URL(string: "https://node.viz.cx")!)

class ClientTest: XCTestCase {
    func testNani() {
        debugPrint(Data(hexEncoded: "79276aea5d4877d9a25892eaa01b0adf019d3e5cb12a97478df3298ccdd01673").base64EncodedString())
    }

    func testGlobalProps() async throws {
        let req = API.GetDynamicGlobalProperties()
        let res = try await client.send(req)
        
        XCTAssertEqual(res.currentSupply.symbol.name, "VIZ")
    }

    func testGetBlock() async throws {
        let req = API.GetBlock(blockNum: 25_199_247)
        let block = try await client.send(req)
        
        XCTAssertEqual(block.previous.num, 25_199_246)
        XCTAssertEqual(block.transactions.count, 2)
    }


    func testBroadcastAward() async throws {
        let key = PrivateKey(
            "5K5exRbTT5d6HnAsNgdFptedttd8w9HnYXz3jfmPbK35GZQXqia"
        )!
        
        let award = Operation.Award(
            initiator: "babin",
            receiver: "babin",
            energy: 1,
            customSequence: 0,
            memo: "",
            beneficiaries: []
        )
        
        let props = try await client.send(
            API.GetDynamicGlobalProperties()
        )
        let expiry = props.time.addingTimeInterval(60)
        let tx = Transaction(
            refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
            refBlockPrefix: props.headBlockId.prefix,
            expiration: expiry,
            operations: [award]
        )
        let stx = try tx.sign(usingKey: key)
        let res = try await client.send(
            API.BroadcastTransaction(transaction: stx)
        )
        
        XCTAssertFalse(res.expired)
        XCTAssert(res.blockNum > props.headBlockId.num)
    }


    func testAccountUpdate() async throws {
        let accountName = "microb"
        let password = "some random generated string"
        
        let masterKey = PrivateKey(seed: accountName + "master" + password)!
        let masterPublicKey = masterKey.createPublic()
        let masterAuthority = Authority(keyAuths: [Authority.Auth(masterPublicKey)])
        
        let activeKey = PrivateKey(seed: accountName + "active" + password)!
        let activePublicKey = activeKey.createPublic()
        let activeAuthority = Authority(keyAuths: [Authority.Auth(activePublicKey)])
        
        let regularKey = PrivateKey(seed: accountName + "regular" + password)!
        let regularPublicKey = regularKey.createPublic()
        let regularAuthority = Authority(keyAuths: [Authority.Auth(regularPublicKey)])
        
        let memoPublicKey = PrivateKey(seed: accountName + "memo" + password)!.createPublic()
        
        let accountUpdate = VIZ.Operation.AccountUpdate(
            account: accountName,
            master: masterAuthority,
            active: activeAuthority,
            regular: regularAuthority,
            memoKey: memoPublicKey
        )
        
        let props = try await client.send(API.GetDynamicGlobalProperties())
        
        let expiry = props.time.addingTimeInterval(60)
        let tx = Transaction(
            refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
            refBlockPrefix: props.headBlockId.prefix,
            expiration: expiry,
            operations: [accountUpdate]
        )
        
        let stx = try tx.sign(usingKey: masterKey)
        let trx = API.BroadcastTransaction(transaction: stx)
        
        do {
            let res = try await client.send(trx)
            XCTAssertFalse(res.expired)
            XCTAssert(res.blockNum > props.headBlockId.num)
        } catch {
            // Если ошибка связана с лимитом обновления мастера, пропускаем тест
            if error.localizedDescription.contains("CHAIN_MASTER_UPDATE_LIMIT") {
                return
            }
            throw error
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

    
    func testTransferBroadcast() async throws {
        let key = PrivateKey("5HzQCAE7CctusYDMJB1T46TLpJq9yQvGzePa5aJedfsgUAUGLzg")!
        let transfer = Operation.Transfer(
            from: "babin",
            to: "babin",
            amount: Asset(0.01, .viz),
            memo: "From viz-swift-lib testing"
        )
        
        let props = try await client.send(API.GetDynamicGlobalProperties())
        
        let expiry = props.time.addingTimeInterval(60)
        let tx = Transaction(
            refBlockNum: UInt16(props.headBlockNumber & 0xFFFF),
            refBlockPrefix: props.headBlockId.prefix,
            expiration: expiry,
            operations: [transfer]
        )
        
        let stx = try tx.sign(usingKey: key, forChain: .mainNet)
        let res = try await client.send(API.BroadcastTransaction(transaction: stx))
        
        XCTAssertFalse(res.expired)
        XCTAssert(res.blockNum > props.headBlockId.num)
    }


    func testGetAccounts() async throws {
        let result = try await client.send(
            API.GetAccounts(names: ["kelechek"])
        )
        guard let account = result.first else {
            return XCTFail("No account returned")
        }
        XCTAssertEqual(account.id, 3775)
        XCTAssertEqual(account.name, "kelechek")
        XCTAssertEqual(
            account.created,
            Date(timeIntervalSince1970: 1577304837)
        )
    }

    
    func testGetAccountHistory() async throws {
        let req = API.GetAccountHistory(
            account: "babin",
            from: -1,
            limit: 100
        )
        
        let result = try await client.send(req)
        XCTAssertEqual(result.count, 101)
    }

    
    func testGetCurrentBlock() async throws {
        let props = try await client.send(API.GetDynamicGlobalProperties())
        
        let currentBlock = Int(props.headBlockId.num)
        let block = try await client.send(
            API.GetBlock(blockNum: currentBlock)
        )
        
        XCTAssertEqual(
            Int(block.previous.num),
            currentBlock - 1
        )
        
        XCTAssertEqual(
            block.timestamp.timeIntervalSince1970,
            Date().timeIntervalSince1970,
            accuracy: 5
        )
    }
    
    func testGetAccountCustomProtocol() async throws {
        let req = API.GetAccount(account: "id", customProtocolId: "V")
        let result = try await client.send(req)
        
        XCTAssertGreaterThanOrEqual(result.customSequence, 37)
        XCTAssertGreaterThanOrEqual(result.customSequenceBlockNum, 65_834_508)
        
        XCTAssertGreaterThanOrEqual(result.currentEnergy, 0)
        XCTAssertLessThanOrEqual(result.currentEnergy, 10_000)
        
        XCTAssertGreaterThan(result.effectiveVestingShares, 5_000_000)
    }
    
    func testGetOpsInBLock() async throws {
        let req = API.GetOpsInBlock(blockNum: 76088750, onlyVirtual: false)
        let result = try await client.send(req)
        XCTAssertEqual(result.count, 4)
        let award = result.first?.operation as? VIZ.Operation.Award
        XCTAssertEqual(award?.energy, 5)
        XCTAssertEqual(award?.initiator, "dice.id")
        XCTAssertEqual(award?.receiver, "magik")
        XCTAssertEqual(award?.customSequence, 0)
        XCTAssertEqual(award?.memo, "🎲")
        XCTAssertEqual(award?.beneficiaries, [VIZ.Operation.Beneficiary(account: "era-oftech", weight: 1000)])
    }
}

