/// VIZ protocol encoding.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation
import OrderedDictionary

/// A type that can be encoded into VIZ binary wire format.
public protocol VIZEncodable: Encodable {
    /// Encode self into VIZ binary format.
    func binaryEncode(to encoder: VIZEncoder) throws
}

/// Default implementation which calls through to `Encodable`.
public extension VIZEncodable {
    func binaryEncode(to encoder: VIZEncoder) throws {
        try self.encode(to: encoder)
    }
}

/// Encodes data into VIZ binary format.
public class VIZEncoder {
    /// All errors which `VIZEncoder` can throw.
    public enum Error: Swift.Error, Sendable {
        /// Thrown if encoder encounters a type that is not conforming to `VIZEncodable`.
        case typeNotConformingToVIZEncodable(String)
        /// Thrown if encoder encounters a type that is not confirming to `Encodable`.
        case typeNotConformingToEncodable(String)
    }

    /// Data buffer holding the encoded bytes.
    /// - Note: Implementers of `VIZEncodable` can write directly into this.
    public var data = Data()

    /// Create a new encoder.
    public init() {}

    /// Convenience for creating an encoder, encoding a value and returning the data.
    public static func encode(_ value: VIZEncodable) throws -> Data {
        let encoder = VIZEncoder()
        try value.binaryEncode(to: encoder)
        return encoder.data
    }

    /// Encodes any `VIZEncodable`.
    /// - Note: Platform specific integer types `Int` and `UInt` are encoded as varints.
    public func encode(_ value: Encodable) throws {
        switch value {
        case let v as Int:
            self.appendVarint(UInt64(v))
        case let v as UInt:
            self.appendVarint(UInt64(v))
        case let v as Array<VIZEncodable>:
            self.appendVarint(UInt64(v.count))
            for i in v {
                try i.binaryEncode(to: self)
            }
            break
        case let v as VIZEncodable:
            try v.binaryEncode(to: self)
        default:
            throw Error.typeNotConformingToVIZEncodable(String(describing: type(of: value)))
        }
    }

    /// Append variable integer to encoder buffer.
    func appendVarint(_ value: UInt64) {
        var v = value
        while v > 127 {
            self.data.append(UInt8(v & 0x7F | 0x80))
            v >>= 7
        }
        self.data.append(UInt8(v))
    }

    /// Append the raw bytes of the parameter to the encoder's data.
    func appendBytes<T>(of value: T) {
        var v = value
        withUnsafeBytes(of: &v) {
            data.append(contentsOf: $0)
        }
    }
}

// Encoder conformance.
// Based on Mike Ash's BinaryEncoder
// https://github.com/mikeash/BinaryCoder
extension VIZEncoder: Encoder {
    public var codingPath: [CodingKey] { return [] }

    public var userInfo: [CodingUserInfoKey: Any] { return [:] }

    public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        return KeyedEncodingContainer(KeyedContainer<Key>(encoder: self))
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }

    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var encoder: VIZEncoder

        var codingPath: [CodingKey] { return [] }

        func encode<T>(_ value: T, forKey _: Key) throws where T: Encodable {
            try self.encoder.encode(value)
        }

        func encodeNil(forKey _: Key) throws {}

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey _: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            return self.encoder.container(keyedBy: keyType)
        }

        func nestedUnkeyedContainer(forKey _: Key) -> UnkeyedEncodingContainer {
            return self.encoder.unkeyedContainer()
        }

        func superEncoder() -> Encoder {
            return self.encoder
        }

        func superEncoder(forKey _: Key) -> Encoder {
            return self.encoder
        }
    }

    private struct UnkeyedContanier: UnkeyedEncodingContainer, SingleValueEncodingContainer {
        var encoder: VIZEncoder

        var codingPath: [CodingKey] { return [] }

        var count: Int { return 0 }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            return self.encoder.container(keyedBy: keyType)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            return self
        }

        func superEncoder() -> Encoder {
            return self.encoder
        }

        func encodeNil() throws {}

        func encode<T>(_ value: T) throws where T: Encodable {
            try self.encoder.encode(value)
        }
    }
}

// MARK: - Default type extensions

extension FixedWidthInteger where Self: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) {
        encoder.appendBytes(of: self.littleEndian)
    }
}

extension Int8: VIZEncodable {}
extension UInt8: VIZEncodable {}
extension Int16: VIZEncodable {}
extension UInt16: VIZEncodable {}
extension Int32: VIZEncodable {}
extension UInt32: VIZEncodable {}
extension Int64: VIZEncodable {}
extension UInt64: VIZEncodable {}

extension String: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) {
        encoder.appendVarint(UInt64(self.utf8.count))
        encoder.data.append(contentsOf: self.utf8)
    }
}

extension Array: VIZEncodable where Element: Encodable {
    public func binaryEncode(to encoder: VIZEncoder) throws {
        encoder.appendVarint(UInt64(self.count))
        for item in self {
            try encoder.encode(item)
        }
    }
}

extension OrderedDictionary: VIZEncodable where Key: VIZEncodable, Value: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) throws {
        encoder.appendVarint(UInt64(self.count))
        for (key, value) in self {
            try encoder.encode(key)
            try encoder.encode(value)
        }
    }
}

extension Date: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) throws {
        try encoder.encode(UInt32(self.timeIntervalSince1970))
    }
}

extension Data: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) {
        encoder.data.append(self)
    }
}

extension Bool: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) {
        encoder.data.append(self ? 1 : 0)
    }
}

extension Optional: VIZEncodable where Wrapped: VIZEncodable {
    public func binaryEncode(to encoder: VIZEncoder) throws {
        if let value = self {
            encoder.data.append(1)
            try encoder.encode(value)
        } else {
            encoder.data.append(0)
        }
    }
}
