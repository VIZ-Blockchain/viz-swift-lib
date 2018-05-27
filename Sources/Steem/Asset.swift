/// Steem token types.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

/// The Steem asset type.
public struct Asset {
    /// Asset symbol type, containing the symbol name and precision.
    public enum Symbol {
        /// The STEEM token.
        case steem
        /// Vesting shares.
        case vests
        /// Steem-backed dollars.
        case sbd
        /// Custom token.
        case custom(name: String, precision: UInt8)
    }

    /// The asset symbol.
    public let symbol: Symbol

    internal let amount: Int64

    /// Create a new `Asset`.
    /// - Parameter value: Amount of tokens.
    /// - Parameter symbol: Token symbol.
    init(_ value: Double, symbol: Symbol = .steem) {
        self.amount = Int64(round(value * pow(10, Double(symbol.precision))))
        self.symbol = symbol
    }

    /// Create a new `Asset` from a string representation.
    /// - Parameter value: String to parse into asset, e.g. `1.000 STEEM`.
    init?(_ value: String) {
        let parts = value.split(separator: " ")
        guard parts.count == 2 else {
            return nil
        }
        let symbol: Symbol
        switch parts[1] {
        case "STEEM":
            symbol = .steem
        case "VESTS":
            symbol = .vests
        case "SBD":
            symbol = .sbd
        default:
            let ap = parts[0].split(separator: ".")
            let precision: UInt8 = ap.count == 2 ? UInt8(ap[1].count) : 1
            symbol = .custom(name: String(parts[1]), precision: precision)
        }
        guard let val = Double(parts[0]) else {
            return nil
        }
        self.init(val, symbol: symbol)
    }
}

extension Asset: SteemEncodable, Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let asset = Asset(value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a valid asset string")
        }
        self = asset
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("TODO")
    }

    public func binaryEncode(to encoder: SteemEncoder) throws {
        try encoder.encode(self.amount)
        try encoder.encode(self.symbol.precision)
        let chars = self.symbol.name.utf8
        for char in chars {
            encoder.data.append(char)
        }
        for _ in 0 ..< 7 - chars.count {
            encoder.data.append(0)
        }
    }
}

extension Asset.Symbol {
    /// Symbol precision.
    var precision: UInt8 {
        switch self {
        case .steem, .sbd:
            return 3
        case .vests:
            return 6
        case let .custom(_, precision):
            return precision
        }
    }

    /// String representation of symbol prefix, e.g. "STEEM".
    public var name: String {
        switch self {
        case .steem:
            return "STEEM"
        case .sbd:
            return "SBD"
        case .vests:
            return "VESTS"
        case let .custom(name, _):
            return name.uppercased()
        }
    }
}