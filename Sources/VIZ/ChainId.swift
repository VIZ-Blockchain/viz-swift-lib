/// VIZ chain identifiers.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

fileprivate let mainNetId = Data(hexEncoded: "2040effda178d4fffff5eab7a915d4019879f5205cc5392e4bcced2b6edda0cd")
fileprivate let testNetId = Data(hexEncoded: "46d82ab7d8db682eb1959aed0ada039a6d49afa1602491f93dde9cac3e8e6c32")

/// Chain id, used to sign transactions.
public enum ChainId: Equatable, Sendable {
    /// The main VIZ network.
    case mainNet
    /// Default testing network id.
    case testNet
    /// Custom chain id.
    case custom(Data)
    
    public init(string: String) {
        let data = Data(hexEncoded: string)
        switch data {
        case mainNetId:
            self = .mainNet
        case testNetId:
            self = .testNet
        default:
            self = .custom(data)
        }
    }
    
    /// The 32-byte chain id.
    public var data: Data {
        switch self {
        case .mainNet:
            return mainNetId
        case .testNet:
            return testNetId
        case let .custom(id):
            return id
        }
    }
}
