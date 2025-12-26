/// VIZ PublicKey implementation.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

/// A VIZ public key.
public struct PublicKey: Equatable, Sendable {
    /// Chain address prefix.
    public enum AddressPrefix: Equatable, Hashable, Sendable {
        case mainNet // VIZ
        case testNet // VIZ
        case custom(String)
    }

    /// Address prefix.
    public let prefix: AddressPrefix

    /// The 33-byte compressed public key.
    public let key: Data

    /// Create a new PublicKey instance.
    /// - Parameter key: 33-byte compressed public key.
    /// - Parameter prefix: Network address prefix.
    public init?(key: Data, prefix: AddressPrefix = .mainNet) {
        guard key.count == 33 else {
            return nil
        }
        self.key = key
        self.prefix = prefix
    }

    /// Create a new PublicKey instance from a VIZ public key address.
    /// - Parameter address: The public key in VIZ address format.
    public init?(_ address: String) {
        let prefix = address.prefix(3)
        guard prefix.count == 3 else {
            return nil
        }
        let key = address.suffix(from: prefix.endIndex)
        guard key.count > 0 else {
            return nil
        }
        guard let keyData = Data(base58CheckEncoded: String(key), .ripemd160) else {
            return nil
        }
        self.prefix = AddressPrefix(String(prefix))
        self.key = keyData
    }

    /// Public key address string.
    public var address: String {
        return String(self.prefix) + self.key.base58CheckEncodedString(.ripemd160)!
    }
}

extension PublicKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key.withUnsafeBytes { $0.load(as: Int.self) } + self.prefix.hashValue)
    }
}

extension PublicKey: LosslessStringConvertible {
    public var description: String { return self.address }
}

extension PublicKey: VIZEncodable, Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let key = PublicKey(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid public key")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self))
    }

    public func binaryEncode(to encoder: VIZEncoder) {
        encoder.data.append(self.key)
    }
}

extension PublicKey.AddressPrefix: ExpressibleByStringLiteral, LosslessStringConvertible {
    public typealias StringLiteralType = String

    /// Create new addres prefix from string.
    public init(_ value: String) {
        if value == "VIZ" {
            self = .mainNet
        } else if value == "VIZTEST" {
            self = .testNet
        } else {
            self = .custom(value)
        }
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// String representation of address prefix, e.g. "VIZ".
    public var description: String {
        switch self {
        case .mainNet:
            return "VIZ"
        case .testNet:
            return "VIZ"
        case let .custom(prefix):
            return prefix.uppercased()
        }
    }
}
