/// VIZ block types.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

/// Type representing a VIZ block ID.
public struct BlockId: Codable, Equatable, Sendable {
    /// The block hash.
    public var hash: Data
    /// The block number.
    public var num: UInt32 {
        return UInt32(bigEndian: self.hash.withUnsafeBytes { $0.load(as: UInt32.self) })
    }

    /// The block prefix.
    public var prefix: UInt32 {
        return UInt32(littleEndian: self.hash.suffix(from: 4).withUnsafeBytes { $0.load(as: UInt32.self) })
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.hash = try container.decode(Data.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.hash)
    }
}

/// Block extensions used for signaling.
public enum BlockExtension: Equatable, Sendable {
    /// Unknown block extension.
    case unknown
    /// Witness version reporting.
    case version(String)
    /// Witness hardfork vote.
    case hardforkVersionVote(String, Date)
    /// HF16: quorum certificate of the parent block.
    case quorumCertificate(BlockQuorumCertificate)
    /// HF16: timeout certificate of the skipped round.
    case timeoutCertificate(BlockTimeoutCertificate)
    /// HF16: proof that a validator voted for two blocks in one round.
    case equivocationProof(BlockEquivocationProof)
    /// HF18: timeout certificate whose votes name the certified block.
    case timeoutCertificateV2(BlockTimeoutCertificateV2)
}

/// One `[validator, value]` pair of a node `flat_map<account_name_type, T>`.
public struct ValidatorEntry<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let validator: String
    public let value: Value

    public init(validator: String, value: Value) {
        self.validator = validator
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.validator = try container.decode(String.self)
        self.value = try container.decode(Value.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.validator)
        try container.encode(self.value)
    }
}

/// `block_qc_certificate` (HF16): >2/3 of scheduled validators signed the parent block.
public struct BlockQuorumCertificate: Codable, Equatable, Sendable {
    public let blockNum: UInt32
    public let blockId: BlockId
    public let round: UInt32
    public let signatures: [ValidatorEntry<Signature>]
}

/// `block_timeout_vote` (HF16).
public struct BlockTimeoutVote: Codable, Equatable, Sendable {
    public let highQcRound: UInt32
    public let signature: Signature
}

/// `block_timeout_certificate` (HF16): a quorum of validators gave up on `round`.
public struct BlockTimeoutCertificate: Codable, Equatable, Sendable {
    public let round: UInt32
    public let votes: [ValidatorEntry<BlockTimeoutVote>]
}

/// `block_timeout_vote_v2` (HF18): the vote also names the block certified at `highQcRound`.
public struct BlockTimeoutVoteV2: Codable, Equatable, Sendable {
    public let highQcRound: UInt32
    public let highQcBlockId: BlockId
    public let signature: Signature
}

/// `block_timeout_certificate_v2` (HF18).
public struct BlockTimeoutCertificateV2: Codable, Equatable, Sendable {
    public let round: UInt32
    public let votes: [ValidatorEntry<BlockTimeoutVoteV2>]
}

/// `block_vote_evidence`: one signed block vote, as gossiped.
public struct BlockVoteEvidence: Codable, Equatable, Sendable {
    public let blockNum: UInt32
    public let blockId: BlockId
    public let signature: Signature
}

/// `block_equivocation_proof` (HF16).
public struct BlockEquivocationProof: Codable, Equatable, Sendable {
    public let validator: String
    public let round: UInt32
    public let first: BlockVoteEvidence
    public let second: BlockVoteEvidence
}

/// Internal protocol for a block header.
fileprivate protocol _BlockHeader: Codable {
    /// The block id of the block preceding this one.
    var previous: BlockId { get }
    /// Time when block was generated.
    var timestamp: Date { get }
    /// Validator who produced it.
    var validator: String { get }
    /// Merkle root hash, ripemd160.
    var transactionMerkleRoot: Data { get }
    /// Block extensions.
    var extensions: [BlockExtension] { get }
}

/// A type representing a VIZ block header.
public struct BlockHeader: _BlockHeader {
    public let previous: BlockId
    public let timestamp: Date
    public let validator: String
    public let transactionMerkleRoot: Data
    public let extensions: [BlockExtension]

    enum CodingKeys: String, CodingKey {
        case previous, timestamp, validator, transactionMerkleRoot, extensions
        case legacyWitness = "witness"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.previous = try c.decode(BlockId.self, forKey: .previous)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.transactionMerkleRoot = try c.decode(Data.self, forKey: .transactionMerkleRoot)
        self.extensions = try c.decode([BlockExtension].self, forKey: .extensions)
        self.validator = try (try? c.decode(String.self, forKey: .validator))
                          ?? c.decode(String.self, forKey: .legacyWitness)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(previous, forKey: .previous)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(validator, forKey: .validator)
        try c.encode(transactionMerkleRoot, forKey: .transactionMerkleRoot)
        try c.encode(extensions, forKey: .extensions)
    }
}

/// A type representing a signed VIZ block header.
public struct SignedBlockHeader: _BlockHeader, Equatable, Sendable {
    public let previous: BlockId
    public let timestamp: Date
    public let validator: String
    public let transactionMerkleRoot: Data
    public let extensions: [BlockExtension]
    public let validatorSignature: Signature

    enum CodingKeys: String, CodingKey {
        case previous, timestamp, validator, transactionMerkleRoot, extensions, validatorSignature
        case legacyWitness = "witness"
        case legacyWitnessSignature = "witnessSignature"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.previous = try c.decode(BlockId.self, forKey: .previous)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.transactionMerkleRoot = try c.decode(Data.self, forKey: .transactionMerkleRoot)
        self.extensions = try c.decode([BlockExtension].self, forKey: .extensions)
        self.validator = try (try? c.decode(String.self, forKey: .validator))
                          ?? c.decode(String.self, forKey: .legacyWitness)
        self.validatorSignature = try (try? c.decode(Signature.self, forKey: .validatorSignature))
                                   ?? c.decode(Signature.self, forKey: .legacyWitnessSignature)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(previous, forKey: .previous)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(validator, forKey: .validator)
        try c.encode(transactionMerkleRoot, forKey: .transactionMerkleRoot)
        try c.encode(extensions, forKey: .extensions)
        try c.encode(validatorSignature, forKey: .validatorSignature)
    }
}

/// A type representing a VIZ block.
public struct SignedBlock: _BlockHeader, Equatable, Sendable {
    /// The transactions included in this block.
    public let transactions: [Transaction]
    /// The block number.
    public var num: UInt32 {
        return self.header.previous.num + 1
    }

    private let header: SignedBlockHeader

    /// Create a new Signed block.
    public init(header: SignedBlockHeader, transactions: [Transaction]) {
        self.header = header
        self.transactions = transactions
    }

    // Header proxy.
    public var previous: BlockId { return self.header.previous }
    public var timestamp: Date { return self.header.timestamp }
    public var validator: String { return self.header.validator }
    public var transactionMerkleRoot: Data { return self.header.transactionMerkleRoot }
    public var extensions: [BlockExtension] { return self.header.extensions }
    public var validatorSignature: Signature { return self.header.validatorSignature }

    private enum Key: CodingKey {
        case transactions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.transactions = try container.decode([Transaction].self, forKey: .transactions)
        self.header = try SignedBlockHeader(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try self.header.encode(to: encoder)
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(self.transactions, forKey: .transactions)
    }
}

extension BlockExtension: Codable {
    private struct HardforkVersionVote: Codable {
        let hfVersion: String
        let hfTime: Date
    }

    // Tags are the node's `block_header_extensions` static_variant indexes (append-only wire format).
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(Int.self)
        switch type {
        case 1:
            self = .version(try container.decode(String.self))
        case 2:
            let vote = try container.decode(HardforkVersionVote.self)
            self = .hardforkVersionVote(vote.hfVersion, vote.hfTime)
        case 3:
            self = .quorumCertificate(try container.decode(BlockQuorumCertificate.self))
        case 4:
            self = .timeoutCertificate(try container.decode(BlockTimeoutCertificate.self))
        case 5:
            self = .equivocationProof(try container.decode(BlockEquivocationProof.self))
        case 6:
            self = .timeoutCertificateV2(try container.decode(BlockTimeoutCertificateV2.self))
        default:
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .version(version):
            try container.encode(1 as Int)
            try container.encode(version)
        case let .hardforkVersionVote(version, time):
            try container.encode(2 as Int)
            try container.encode(HardforkVersionVote(hfVersion: version, hfTime: time))
        case let .quorumCertificate(value):
            try container.encode(3 as Int)
            try container.encode(value)
        case let .timeoutCertificate(value):
            try container.encode(4 as Int)
            try container.encode(value)
        case let .equivocationProof(value):
            try container.encode(5 as Int)
            try container.encode(value)
        case let .timeoutCertificateV2(value):
            try container.encode(6 as Int)
            try container.encode(value)
        case .unknown:
            break
        }
    }
}

// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension BlockHeader {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }
}

extension SignedBlockHeader {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }

    @available(*, deprecated, renamed: "validatorSignature")
    public var witnessSignature: Signature { validatorSignature }
}

extension SignedBlock {
    @available(*, deprecated, renamed: "validator")
    public var witness: String { validator }

    @available(*, deprecated, renamed: "validatorSignature")
    public var witnessSignature: Signature { validatorSignature }
}
