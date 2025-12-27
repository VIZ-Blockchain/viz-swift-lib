import Foundation
import VIZ
import XCTest

class PerformanceTest: XCTestCase {
    func testSign() {
        let key = PrivateKey("5JEB2fkmEqHSfGqL96eTtQ2emYodeTBBnXvETwe2vUSMe4pxdLj")!
        let message = Data(count: 32)
        self.measure {
            for _ in 0 ... 100 {
                _ = try! key.sign(message: message)
            }
        }
    }

    func testEncode() {
        let award = Operation.Award(initiator: "foo", receiver: "bar", energy: 10000, customSequence: 0, memo: "baz", beneficiaries: [Operation.Beneficiary(account: "qux", weight: 1000)])
        let transfer = Operation.Transfer(from: "foo", to: "bar", amount: Asset(100.500, Asset.Symbol.viz), memo: "baz")
        let txn = Transaction(refBlockNum: 0, refBlockPrefix: 0, expiration: Date(), operations: [award, transfer])
        self.measure {
            for _ in 0 ... 1000 {
                _ = try! VIZEncoder.encode(txn)
            }
        }
    }
}
