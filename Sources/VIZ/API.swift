/// VIZ RPC requests and responses.
/// - Author: Johan Nordberg <johan@steemit.com>
/// - Author: Iain Maitland <imaitland@steemit.com>

import Foundation

/// VIZ RPC API request- and response-types.
public struct API {

    public struct DynamicGlobalProperties: Decodable {
        public let headBlockNumber: UInt32
        public let headBlockId: BlockId
        public let time: Date
        public let genesisTime: Date
        public let currentWitness: String
        public let committeeFund: Asset
        public let committeeRequests: UInt32
        public let currentSupply: Asset
        public let totalVestingFund: Asset
        public let totalVestingShares: Asset
        public let totalRewardFund: Asset
        public let totalRewardShares: String
        public let inflationCalcBlockNum: UInt32
        public let inflationWitnessPercent: Int16
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
    }

    public struct GetDynamicGlobalProperties: Request {
        public typealias Response = DynamicGlobalProperties
        public let method = "get_dynamic_global_properties"
        public let params: RequestParams<[String]>? = RequestParams([])
        public init() {}
    }

    public struct TransactionConfirmation: Decodable {
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

    public struct Share: Decodable {
        public let value: Int64
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int64.self) {
                self.value = intValue
            } else {
                self.value = Int64(try container.decode(String.self)) ?? 0
            }
        }
    }

    /// The "extended" account object returned by get_accounts.
    public struct ExtendedAccount: Decodable {
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
        public let witnessesVotedFor: UInt16
        public let witnessesVoteWeight: Share
        public let lastPost: Date
        public let lastRootPost: Date
        public let averageBandwidth: Share
        public let lifetimeBandwidth: Share
        public let lastBandwidthUpdate: Date
        public let witnessVotes: [String]
        public let valid: Bool
        public let accountSeller: String
        public let accountOfferPrice: Asset
        public let accountOnSale: Bool
        public let subaccountSeller: String
        public let subaccountOfferPrice: Asset
        public let subaccountOnSale: Bool
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

    public struct OperationObject: Decodable {
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

    public struct AccountHistoryObject: Decodable {
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
}

