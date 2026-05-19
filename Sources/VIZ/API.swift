/// VIZ RPC requests and responses.
/// - Author: Johan Nordberg <johan@steemit.com>
/// - Author: Iain Maitland <imaitland@steemit.com>
/// - Author: Vladimir Babin <vovababin@gmail.com>

import Foundation

/// VIZ RPC API request- and response-types.
public struct API {
    
    public static let CHAIN_ENERGY_REGENERATION_SECONDS: Double = 5*60*60*24 // 5 days

    public struct DynamicGlobalProperties: Decodable, Sendable {
        public let headBlockNumber: UInt32
        public let headBlockId: BlockId
        public let time: Date
        public let genesisTime: Date
        public let currentValidator: String
        public let committeeFund: Asset
        public let committeeRequests: UInt32
        public let currentSupply: Asset
        public let totalVestingFund: Asset
        public let totalVestingShares: Asset
        public let totalRewardFund: Asset
        public let totalRewardShares: String
        public let inflationCalcBlockNum: UInt32
        public let inflationValidatorPercent: Int16
        public let inflationRatio: Int16
        public let averageBlockSize: UInt32
        public let maximumBlockSize: UInt32
        public let currentAslot: UInt32
        public let recentSlotsFilled: String
        public let participationCount: UInt32
        public let lastIrreversibleBlockNum: UInt32
        public let maxVirtualBandwidth: String
        public let currentReserveRatio: UInt64
        public let voteRegenerationPerDay: UInt32

        // CodingKey raw values must be camelCase because the decoder applies
        // .convertFromSnakeCase before matching. Legacy keys carry the pre-rename
        // camelCase form so JSON `current_witness` / `inflation_witness_percent`
        // still decode into the new validator-named properties.
        enum CodingKeys: String, CodingKey {
            case headBlockNumber, headBlockId, time, genesisTime,
                 currentValidator,
                 committeeFund, committeeRequests, currentSupply,
                 totalVestingFund, totalVestingShares, totalRewardFund, totalRewardShares,
                 inflationCalcBlockNum,
                 inflationValidatorPercent,
                 inflationRatio, averageBlockSize, maximumBlockSize, currentAslot,
                 recentSlotsFilled, participationCount, lastIrreversibleBlockNum,
                 maxVirtualBandwidth, currentReserveRatio, voteRegenerationPerDay
            case legacyCurrentWitness          = "currentWitness"
            case legacyInflationWitnessPercent = "inflationWitnessPercent"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.headBlockNumber = try c.decode(UInt32.self, forKey: .headBlockNumber)
            self.headBlockId = try c.decode(BlockId.self, forKey: .headBlockId)
            self.time = try c.decode(Date.self, forKey: .time)
            self.genesisTime = try c.decode(Date.self, forKey: .genesisTime)
            self.committeeFund = try c.decode(Asset.self, forKey: .committeeFund)
            self.committeeRequests = try c.decode(UInt32.self, forKey: .committeeRequests)
            self.currentSupply = try c.decode(Asset.self, forKey: .currentSupply)
            self.totalVestingFund = try c.decode(Asset.self, forKey: .totalVestingFund)
            self.totalVestingShares = try c.decode(Asset.self, forKey: .totalVestingShares)
            self.totalRewardFund = try c.decode(Asset.self, forKey: .totalRewardFund)
            self.totalRewardShares = try c.decode(String.self, forKey: .totalRewardShares)
            self.inflationCalcBlockNum = try c.decode(UInt32.self, forKey: .inflationCalcBlockNum)
            self.inflationRatio = try c.decode(Int16.self, forKey: .inflationRatio)
            self.averageBlockSize = try c.decode(UInt32.self, forKey: .averageBlockSize)
            self.maximumBlockSize = try c.decode(UInt32.self, forKey: .maximumBlockSize)
            self.currentAslot = try c.decode(UInt32.self, forKey: .currentAslot)
            self.recentSlotsFilled = try c.decode(String.self, forKey: .recentSlotsFilled)
            self.participationCount = try c.decode(UInt32.self, forKey: .participationCount)
            self.lastIrreversibleBlockNum = try c.decode(UInt32.self, forKey: .lastIrreversibleBlockNum)
            self.maxVirtualBandwidth = try c.decode(String.self, forKey: .maxVirtualBandwidth)
            self.currentReserveRatio = try c.decode(UInt64.self, forKey: .currentReserveRatio)
            self.voteRegenerationPerDay = try c.decode(UInt32.self, forKey: .voteRegenerationPerDay)
            self.currentValidator = try (try? c.decode(String.self, forKey: .currentValidator))
                ?? c.decode(String.self, forKey: .legacyCurrentWitness)
            self.inflationValidatorPercent = try (try? c.decode(Int16.self, forKey: .inflationValidatorPercent))
                ?? c.decode(Int16.self, forKey: .legacyInflationWitnessPercent)
        }
    }

    public struct GetDynamicGlobalProperties: Request {
        public typealias Response = DynamicGlobalProperties
        public let method = "get_dynamic_global_properties"
        public let params: RequestParams<[String]>? = RequestParams([])
        public init() {}
    }

    public struct TransactionConfirmation: Decodable, Sendable {
        public let id: Data
        public let blockNum: Int32
        public let trxNum: Int32
        public let expired: Bool
    }

    public struct BroadcastTransaction: Request {
        public typealias Response = TransactionConfirmation
        public let method = "broadcast_transaction_synchronous"
        public let params: RequestParams<SignedTransaction>?
        public init(transaction: SignedTransaction) {
            self.params = RequestParams([transaction])
        }
    }

    public struct GetBlock: Request {
        public typealias Response = SignedBlock
        public let method = "get_block"
        public let params: RequestParams<Int>?
        public init(blockNum: Int) {
            self.params = RequestParams([blockNum])
        }
    }

    public struct Share: Decodable, Sendable {
        public let value: Int64
        
        public init(_ value: Int64) {
            self.value = value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int64.self) {
                self.value = intValue
            } else {
                // TODO: should throw DecodingError on parse failure instead of returning 0
                self.value = Int64(try container.decode(String.self)) ?? 0
            }
        }
    }

    /// The "extended" account object returned by get_accounts.
    public struct ExtendedAccount: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let masterAuthority: Authority
        public let activeAuthority: Authority
        public let regularAuthority: Authority
        public let memoKey: PublicKey
        public let jsonMetadata: String
        public let proxy: String
        public let referrer: String
        public let lastMasterUpdate: Date
        public let lastAccountUpdate: Date
        public let created: Date
        public let recoveryAccount: String
        public let lastAccountRecovery: Date
        public let awardedRshares: UInt64
        public let customSequence: UInt64
        public let customSequenceBlockNum: UInt64
        public let energy: Int32
        public let lastVoteTime: Date
        public let balance: Asset
        public let receiverAwards: UInt64
        public let benefactorAwards: UInt64
        public let vestingShares: Asset
        public let delegatedVestingShares: Asset
        public let receivedVestingShares: Asset
        public let vestingWithdrawRate: Asset
        public let nextVestingWithdrawal: Date
        public let withdrawn: Share
        public let toWithdraw: Share
        public let withdrawRoutes: UInt16
        public let proxiedVsfVotes: [Share]
        public let validatorsVotedFor: UInt16
        public let validatorsVoteWeight: Share
        public let lastPost: Date
        public let lastRootPost: Date
        public let averageBandwidth: Share
        public let lifetimeBandwidth: Share
        public let lastBandwidthUpdate: Date
        public let validatorVotes: [String]
        public let valid: Bool
        public let accountSeller: String
        public let accountOfferPrice: Asset
        public let accountOnSale: Bool
        public let subaccountSeller: String
        public let subaccountOfferPrice: Asset
        public let subaccountOnSale: Bool

        public var effectiveVestingShares: Double {
            vestingShares.resolvedAmount
            + receivedVestingShares.resolvedAmount
            - delegatedVestingShares.resolvedAmount
        }

        // TODO: take a Date parameter for testability instead of reading Date() implicitly
        public var currentEnergy: Int {
            let deltaTime = Date().timeIntervalSince(lastVoteTime)
            var e = Float64(energy) + (deltaTime * 10000 / CHAIN_ENERGY_REGENERATION_SECONDS)
            if e > 10000 {
                e = 10000
            } else if e < 0 {
                e = 0
            }
            return Int(e)
        }

        // Explicit memberwise init so callers (including tests) can construct one
        // with the new validator-named labels. Adding a custom init(from:) below
        // suppresses Swift's auto-synthesized memberwise init, so this is required.
        public init(
            id: Int, name: String,
            masterAuthority: Authority, activeAuthority: Authority, regularAuthority: Authority,
            memoKey: PublicKey, jsonMetadata: String,
            proxy: String, referrer: String,
            lastMasterUpdate: Date, lastAccountUpdate: Date, created: Date,
            recoveryAccount: String, lastAccountRecovery: Date,
            awardedRshares: UInt64, customSequence: UInt64, customSequenceBlockNum: UInt64,
            energy: Int32, lastVoteTime: Date,
            balance: Asset, receiverAwards: UInt64, benefactorAwards: UInt64,
            vestingShares: Asset, delegatedVestingShares: Asset, receivedVestingShares: Asset,
            vestingWithdrawRate: Asset, nextVestingWithdrawal: Date,
            withdrawn: Share, toWithdraw: Share, withdrawRoutes: UInt16,
            proxiedVsfVotes: [Share],
            validatorsVotedFor: UInt16, validatorsVoteWeight: Share,
            lastPost: Date, lastRootPost: Date,
            averageBandwidth: Share, lifetimeBandwidth: Share, lastBandwidthUpdate: Date,
            validatorVotes: [String], valid: Bool,
            accountSeller: String, accountOfferPrice: Asset, accountOnSale: Bool,
            subaccountSeller: String, subaccountOfferPrice: Asset, subaccountOnSale: Bool
        ) {
            self.id = id; self.name = name
            self.masterAuthority = masterAuthority; self.activeAuthority = activeAuthority; self.regularAuthority = regularAuthority
            self.memoKey = memoKey; self.jsonMetadata = jsonMetadata
            self.proxy = proxy; self.referrer = referrer
            self.lastMasterUpdate = lastMasterUpdate; self.lastAccountUpdate = lastAccountUpdate; self.created = created
            self.recoveryAccount = recoveryAccount; self.lastAccountRecovery = lastAccountRecovery
            self.awardedRshares = awardedRshares; self.customSequence = customSequence; self.customSequenceBlockNum = customSequenceBlockNum
            self.energy = energy; self.lastVoteTime = lastVoteTime
            self.balance = balance; self.receiverAwards = receiverAwards; self.benefactorAwards = benefactorAwards
            self.vestingShares = vestingShares; self.delegatedVestingShares = delegatedVestingShares; self.receivedVestingShares = receivedVestingShares
            self.vestingWithdrawRate = vestingWithdrawRate; self.nextVestingWithdrawal = nextVestingWithdrawal
            self.withdrawn = withdrawn; self.toWithdraw = toWithdraw; self.withdrawRoutes = withdrawRoutes
            self.proxiedVsfVotes = proxiedVsfVotes
            self.validatorsVotedFor = validatorsVotedFor; self.validatorsVoteWeight = validatorsVoteWeight
            self.lastPost = lastPost; self.lastRootPost = lastRootPost
            self.averageBandwidth = averageBandwidth; self.lifetimeBandwidth = lifetimeBandwidth; self.lastBandwidthUpdate = lastBandwidthUpdate
            self.validatorVotes = validatorVotes; self.valid = valid
            self.accountSeller = accountSeller; self.accountOfferPrice = accountOfferPrice; self.accountOnSale = accountOnSale
            self.subaccountSeller = subaccountSeller; self.subaccountOfferPrice = subaccountOfferPrice; self.subaccountOnSale = subaccountOnSale
        }

        // CodingKey raw values must be camelCase because the decoder applies
        // .convertFromSnakeCase before matching. Legacy keys carry the pre-rename
        // camelCase form so JSON `witnesses_voted_for` / `witnesses_vote_weight`
        // / `witness_votes` still decode into the new validator-named properties.
        enum CodingKeys: String, CodingKey {
            case id, name, masterAuthority, activeAuthority, regularAuthority,
                 memoKey, jsonMetadata, proxy, referrer,
                 lastMasterUpdate, lastAccountUpdate, created,
                 recoveryAccount, lastAccountRecovery,
                 awardedRshares, customSequence, customSequenceBlockNum,
                 energy, lastVoteTime, balance, receiverAwards, benefactorAwards,
                 vestingShares, delegatedVestingShares, receivedVestingShares,
                 vestingWithdrawRate, nextVestingWithdrawal,
                 withdrawn, toWithdraw, withdrawRoutes, proxiedVsfVotes,
                 validatorsVotedFor, validatorsVoteWeight,
                 lastPost, lastRootPost,
                 averageBandwidth, lifetimeBandwidth, lastBandwidthUpdate,
                 validatorVotes, valid,
                 accountSeller, accountOfferPrice, accountOnSale,
                 subaccountSeller, subaccountOfferPrice, subaccountOnSale
            case legacyWitnessesVotedFor   = "witnessesVotedFor"
            case legacyWitnessesVoteWeight = "witnessesVoteWeight"
            case legacyWitnessVotes        = "witnessVotes"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            self.masterAuthority = try c.decode(Authority.self, forKey: .masterAuthority)
            self.activeAuthority = try c.decode(Authority.self, forKey: .activeAuthority)
            self.regularAuthority = try c.decode(Authority.self, forKey: .regularAuthority)
            self.memoKey = try c.decode(PublicKey.self, forKey: .memoKey)
            self.jsonMetadata = try c.decode(String.self, forKey: .jsonMetadata)
            self.proxy = try c.decode(String.self, forKey: .proxy)
            self.referrer = try c.decode(String.self, forKey: .referrer)
            self.lastMasterUpdate = try c.decode(Date.self, forKey: .lastMasterUpdate)
            self.lastAccountUpdate = try c.decode(Date.self, forKey: .lastAccountUpdate)
            self.created = try c.decode(Date.self, forKey: .created)
            self.recoveryAccount = try c.decode(String.self, forKey: .recoveryAccount)
            self.lastAccountRecovery = try c.decode(Date.self, forKey: .lastAccountRecovery)
            self.awardedRshares = try c.decode(UInt64.self, forKey: .awardedRshares)
            self.customSequence = try c.decode(UInt64.self, forKey: .customSequence)
            self.customSequenceBlockNum = try c.decode(UInt64.self, forKey: .customSequenceBlockNum)
            self.energy = try c.decode(Int32.self, forKey: .energy)
            self.lastVoteTime = try c.decode(Date.self, forKey: .lastVoteTime)
            self.balance = try c.decode(Asset.self, forKey: .balance)
            self.receiverAwards = try c.decode(UInt64.self, forKey: .receiverAwards)
            self.benefactorAwards = try c.decode(UInt64.self, forKey: .benefactorAwards)
            self.vestingShares = try c.decode(Asset.self, forKey: .vestingShares)
            self.delegatedVestingShares = try c.decode(Asset.self, forKey: .delegatedVestingShares)
            self.receivedVestingShares = try c.decode(Asset.self, forKey: .receivedVestingShares)
            self.vestingWithdrawRate = try c.decode(Asset.self, forKey: .vestingWithdrawRate)
            self.nextVestingWithdrawal = try c.decode(Date.self, forKey: .nextVestingWithdrawal)
            self.withdrawn = try c.decode(Share.self, forKey: .withdrawn)
            self.toWithdraw = try c.decode(Share.self, forKey: .toWithdraw)
            self.withdrawRoutes = try c.decode(UInt16.self, forKey: .withdrawRoutes)
            self.proxiedVsfVotes = try c.decode([Share].self, forKey: .proxiedVsfVotes)
            self.lastPost = try c.decode(Date.self, forKey: .lastPost)
            self.lastRootPost = try c.decode(Date.self, forKey: .lastRootPost)
            self.averageBandwidth = try c.decode(Share.self, forKey: .averageBandwidth)
            self.lifetimeBandwidth = try c.decode(Share.self, forKey: .lifetimeBandwidth)
            self.lastBandwidthUpdate = try c.decode(Date.self, forKey: .lastBandwidthUpdate)
            self.valid = try c.decode(Bool.self, forKey: .valid)
            self.accountSeller = try c.decode(String.self, forKey: .accountSeller)
            self.accountOfferPrice = try c.decode(Asset.self, forKey: .accountOfferPrice)
            self.accountOnSale = try c.decode(Bool.self, forKey: .accountOnSale)
            self.subaccountSeller = try c.decode(String.self, forKey: .subaccountSeller)
            self.subaccountOfferPrice = try c.decode(Asset.self, forKey: .subaccountOfferPrice)
            self.subaccountOnSale = try c.decode(Bool.self, forKey: .subaccountOnSale)
            self.validatorsVotedFor = try (try? c.decode(UInt16.self, forKey: .validatorsVotedFor))
                ?? c.decode(UInt16.self, forKey: .legacyWitnessesVotedFor)
            self.validatorsVoteWeight = try (try? c.decode(Share.self, forKey: .validatorsVoteWeight))
                ?? c.decode(Share.self, forKey: .legacyWitnessesVoteWeight)
            self.validatorVotes = try (try? c.decode([String].self, forKey: .validatorVotes))
                ?? c.decode([String].self, forKey: .legacyWitnessVotes)
        }
    }

    /// Fetch accounts.
    public struct GetAccounts: Request {
        public typealias Response = [ExtendedAccount]
        public let method = "get_accounts"
        public let params: RequestParams<[String]>?
        public init(names: [String]) {
            self.params = RequestParams([names])
        }
    }

    public struct OperationObject: Decodable, Sendable {
        public let trxId: Data
        public let block: UInt32
        public let trxInBlock: UInt32
        public let opInTrx: UInt32
        public let virtualOp: UInt32
        public let timestamp: Date
        private let op: AnyOperation
        public var operation: OperationType {
            return self.op.operation
        }
    }

    public struct AccountHistoryObject: Decodable, Sendable {
        public let id: UInt32
        public let value: OperationObject
        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.id = try container.decode(UInt32.self)
            self.value = try container.decode(OperationObject.self)
        }
    }

    public struct GetAccountHistory: Request, Encodable {
        public typealias Response = [AccountHistoryObject]
        public let method = "get_account_history"
        public var params: RequestParams<AnyEncodable>? {
            return RequestParams([AnyEncodable(self.account), AnyEncodable(self.from), AnyEncodable(self.limit)])
        }

        public var account: String
        public var from: Int
        public var limit: Int
        public init(account: String, from: Int = -1, limit: Int = 100) {
            self.account = account
            self.from = from
            self.limit = limit
        }
    }
    
    public struct GetAccount: Request, Encodable {
        public typealias Response = ExtendedAccount
        public let method = "get_account"
        public var params: RequestParams<AnyEncodable>? {
            return RequestParams([AnyEncodable(self.account), AnyEncodable(self.customProtocolId)])
        }
        
        public var account: String
        public var customProtocolId: String
        public init(account: String, customProtocolId: String) {
            self.account = account
            self.customProtocolId = customProtocolId
        }
    }
    
    public struct GetOpsInBlock: Request, Encodable {
        public typealias Response = [OperationObject]
        public let method = "get_ops_in_block"
        public var params: RequestParams<AnyEncodable>? {
            return RequestParams([AnyEncodable(self.blockNum), AnyEncodable(self.onlyVirtual)])
        }

        public var blockNum: Int
        public var onlyVirtual: Bool
        public init(blockNum: Int, onlyVirtual: Bool) {
            self.blockNum = blockNum
            self.onlyVirtual = onlyVirtual
        }
    }
}

// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension API.DynamicGlobalProperties {
    @available(*, deprecated, renamed: "currentValidator")
    public var currentWitness: String { currentValidator }

    @available(*, deprecated, renamed: "inflationValidatorPercent")
    public var inflationWitnessPercent: Int16 { inflationValidatorPercent }
}

extension API.ExtendedAccount {
    @available(*, deprecated, renamed: "validatorsVotedFor")
    public var witnessesVotedFor: UInt16 { validatorsVotedFor }

    @available(*, deprecated, renamed: "validatorsVoteWeight")
    public var witnessesVoteWeight: API.Share { validatorsVoteWeight }

    @available(*, deprecated, renamed: "validatorVotes")
    public var witnessVotes: [String] { validatorVotes }
}
