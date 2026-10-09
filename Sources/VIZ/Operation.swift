/// VIZ operation types.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

/// A type that represents a operation on the VIZ blockchain.
public protocol OperationType: VIZCodable, Sendable {
    /// Whether the operation is virtual or not.
    var isVirtual: Bool { get }
}

extension OperationType {
    public var isVirtual: Bool { return false }
}

/// Namespace for all available VIZ operations.
public struct Operation {
    /// Voting operation, votes for content.
    public struct Vote: OperationType, Equatable {
        /// The account that is casting the vote.
        public var voter: String
        /// The account name that is receieving the vote.
        public var author: String
        /// The content being voted for.
        public var permlink: String
        /// The vote weight. 100% = 10000. A negative value is a "flag".
        public var weight: Int16 = 10000

        /// Create a new vote operation.
        /// - Parameter voter: The account that is voting for the content.
        /// - Parameter author: The account that is recieving the vote.
        /// - Parameter permlink: The permalink of the content to be voted on,
        /// - Parameter weight: The weight to use when voting, a percentage expressed as -10000 to 10000.
        public init(voter: String, author: String, permlink: String, weight: Int16 = 10000) {
            self.voter = voter
            self.author = author
            self.permlink = permlink
            self.weight = weight
        }
    }

    /// Content operation, creates comments and posts.
    public struct Content: OperationType, Equatable {
        /// The parent content author, left blank for top level posts.
        public var parentAuthor: String = ""
        /// The parent content permalink, left blank for top level posts.
        public var parentPermlink: String = ""
        /// The account name of the post creator.
        public var author: String
        /// The content permalink.
        public var permlink: String
        /// The content title.
        public var title: String
        /// The content body.
        public var body: String
        /// Additional content metadata.
        public var jsonMetadata: JSONString

        public init(
            title: String,
            body: String,
            author: String,
            permlink: String,
            parentAuthor: String = "",
            parentPermlink: String = "",
            jsonMetadata: JSONString = ""
        ) {
            self.parentAuthor = parentAuthor
            self.parentPermlink = parentPermlink
            self.author = author
            self.permlink = permlink
            self.title = title
            self.body = body
            self.jsonMetadata = jsonMetadata
        }

        /// Content metadata.
        var metadata: [String: Any]? {
            set { self.jsonMetadata.object = newValue }
            get { return self.jsonMetadata.object }
        }
    }

    /// Transfers assets from one account to another.
    public struct Transfer: OperationType, Equatable {
        /// Account name of the sender.
        public var from: String
        /// Account name of the reciever.
        public var to: String
        /// Amount to transfer.
        public var amount: Asset
        /// Note attached to transaction.
        public var memo: String

        public init(from: String, to: String, amount: Asset, memo: String = "") {
            self.from = from
            self.to = to
            self.amount = amount
            self.memo = memo
        }
    }

    /// Converts VIZ to VESTS, aka. "Powering Up".
    public struct TransferToVesting: OperationType, Equatable {
        /// Account name of sender.
        public var from: String
        /// Account name of reciever.
        public var to: String
        /// Amount to power up, must be VIZ.
        public var amount: Asset

        public init(from: String, to: String, amount: Asset) {
            self.from = from
            self.to = to
            self.amount = amount
        }
    }

    /// Starts a vesting withdrawal, aka. "Powering Down".
    public struct WithdrawVesting: OperationType, Equatable {
        /// Account that is powering down.
        public var account: String
        /// Amount that is powered down, must be VESTS.
        public var vestingShares: Asset

        public init(account: String, vestingShares: Asset) {
            self.account = account
            self.vestingShares = vestingShares
        }
    }

    /// Convert operation (Steem-legacy).
    ///
    /// - Note: VIZ has no `convert` operation and no matching `OperationId`, so encoding a
    ///   `Convert` throws. The type is retained only for source compatibility, like other
    ///   Steem-legacy operations kept for decoding completeness.
    public struct Convert: OperationType, Equatable {
        public var owner: String
        public var requestid: UInt32
        public var amount: Asset

        public init(owner: String, requestid: UInt32, amount: Asset) {
            self.owner = owner
            self.requestid = requestid
            self.amount = amount
        }
    }

    /// Creates a new account.
    public struct AccountCreate: OperationType, Equatable {
        public var fee: Asset
        public var creator: String
        public var newAccountName: String
        public var master: Authority
        public var active: Authority
        public var regular: Authority
        public var memoKey: PublicKey
        public var jsonMetadata: JSONString

        public init(
            fee: Asset,
            creator: String,
            newAccountName: String,
            master: Authority,
            active: Authority,
            regular: Authority,
            memoKey: PublicKey,
            jsonMetadata: JSONString = ""
        ) {
            self.fee = fee
            self.creator = creator
            self.newAccountName = newAccountName
            self.master = master
            self.active = active
            self.regular = regular
            self.memoKey = memoKey
            self.jsonMetadata = jsonMetadata
        }

        /// Account metadata.
        var metadata: [String: Any]? {
            set { self.jsonMetadata.object = newValue }
            get { return self.jsonMetadata.object }
        }
    }

    /// Updates an account.
    public struct AccountUpdate: OperationType, Equatable {
        public var account: String
        public var masterIsSet: Bool
        public var master: Authority?
        public var activeIsSet: Bool
        public var active: Authority?
        public var regularIsSet: Bool
        public var regular: Authority?
        public var memoKey: PublicKey
        public var jsonMetadata: String

        public init(
            account: String,
            master: Authority?,
            active: Authority?,
            regular: Authority?,
            memoKey: PublicKey,
            jsonMetadata: String = ""
        ) {
            self.account = account
            self.master = master
            self.masterIsSet = master != nil
            self.active = active
            self.activeIsSet = active != nil
            self.regular = regular
            self.regularIsSet = regular != nil
            self.memoKey = memoKey
            self.jsonMetadata = jsonMetadata
        }
    }

    /// Registers or updates validators.
    public struct ValidatorUpdate: OperationType, Equatable {
        /// Validator chain properties.
        public struct Properties: VIZCodable, Equatable, Sendable {
//            public var accountCreationFee: Asset
//            public var maximumBlockSize: UInt32
//            public var sbdInterestRate: UInt16
        }

        public var owner: String
        public var url: String
        public var blockSigningKey: PublicKey
        public var props: Properties
        public var fee: Asset

        public init(
            owner: String,
            url: String,
            blockSigningKey: PublicKey,
            props: Properties,
            fee: Asset
        ) {
            self.owner = owner
            self.url = url
            self.blockSigningKey = blockSigningKey
            self.props = props
            self.fee = fee
        }
    }

    /// Votes for a validator.
    public struct AccountValidatorVote: OperationType, Equatable {
        public var account: String
        public var validator: String
        public var approve: Bool

        public init(account: String, validator: String, approve: Bool) {
            self.account = account
            self.validator = validator
            self.approve = approve
        }

        @available(*, deprecated, message: "Use init(account:validator:approve:)")
        public init(account: String, witness: String, approve: Bool) {
            self.init(account: account, validator: witness, approve: approve)
        }

        @available(*, deprecated, renamed: "validator")
        public var witness: String {
            get { validator }
            set { validator = newValue }
        }

        enum CodingKeys: String, CodingKey {
            case account, validator, approve
            case legacyWitness = "witness"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.account = try c.decode(String.self, forKey: .account)
            self.approve = try c.decode(Bool.self,   forKey: .approve)
            self.validator = try (try? c.decode(String.self, forKey: .validator))
                          ?? c.decode(String.self, forKey: .legacyWitness)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(account,   forKey: .account)
            try c.encode(validator, forKey: .validator)
            try c.encode(approve,   forKey: .approve)
        }
    }

    /// Sets a validator voting proxy.
    public struct AccountValidatorProxy: OperationType, Equatable {
        public var account: String
        public var proxy: String

        public init(account: String, proxy: String) {
            self.account = account
            self.proxy = proxy
        }
    }

    /// Custom operation — carries an arbitrary JSON payload authorized by the
    /// listed active and/or regular authorities.
    ///
    /// Wire layout matches the VIZ `custom_operation`:
    /// `required_active_auths`, `required_regular_auths`, `id` (string, < 32 chars), `json`.
    public struct Custom: OperationType, Equatable {
        public var requiredActiveAuths: [String]
        public var requiredRegularAuths: [String]
        public var id: String
        public var json: JSONString

        public init(
            requiredActiveAuths: [String],
            requiredRegularAuths: [String],
            id: String,
            json: JSONString
        ) {
            self.requiredActiveAuths = requiredActiveAuths
            self.requiredRegularAuths = requiredRegularAuths
            self.id = id
            self.json = json
        }

        /// Legacy initializer preserving the previous (Steem-shaped) field layout.
        /// The VIZ `custom` op carries a JSON payload keyed by a string `id`; the old
        /// `id: UInt16` / `data: Data` shape never validated on-chain. `data` is
        /// interpreted as UTF-8 JSON.
        @available(*, deprecated, message: "VIZ `custom` uses id: String and json: JSONString — use init(requiredActiveAuths:requiredRegularAuths:id:json:)")
        public init(
            requiredRegularAuths: [String],
            requiredActiveAuths: [String],
            id: UInt16,
            data: Data
        ) {
            self.requiredActiveAuths = requiredActiveAuths
            self.requiredRegularAuths = requiredRegularAuths
            self.id = String(id)
            self.json = JSONString(jsonString: String(decoding: data, as: UTF8.self))
        }
    }

    /// Reports a producer who signs two blocks at the same time.
    public struct ReportOverProduction: OperationType, Equatable {
        public var reporter: String
        public var firstBlock: SignedBlockHeader
        public var secondBlock: SignedBlockHeader

        public init(
            reporter: String,
            firstBlock: SignedBlockHeader,
            secondBlock: SignedBlockHeader
        ) {
            self.reporter = reporter
            self.firstBlock = firstBlock
            self.secondBlock = secondBlock
        }
    }

    /// Deletes a comment.
    public struct DeleteContent: OperationType, Equatable {
        public var author: String
        public var permlink: String

        public init(author: String, permlink: String) {
            self.author = author
            self.permlink = permlink
        }
    }

    /// A custom JSON operation.
    ///
    /// - Warning: VIZ has no `custom_json` operation; op id 10 (`custom`) carries the
    ///   JSON payload and maps to ``Operation/Custom``. This type is retained only for
    ///   source compatibility and does not correspond to any on-chain operation.
    @available(*, deprecated, message: "VIZ has no custom_json op; use Operation.Custom for the `custom` op id")
    public struct CustomJson: OperationType, Equatable {
        public var requiredAuths: [String]
        public var requiredPostingAuths: [String]
        public var id: String
        public var json: JSONString

        public init(
            requiredAuths: [String],
            requiredPostingAuths: [String],
            id: String,
            json: JSONString
        ) {
            self.requiredAuths = requiredAuths
            self.requiredPostingAuths = requiredPostingAuths
            self.id = id
            self.json = json
        }
    }

    /// Sets comment options.
    public struct CommentOptions: OperationType, Equatable {
        public struct BeneficiaryRoute: VIZCodable, Equatable, Sendable {
            public var account: String
            public var weight: UInt16
        }

        /// Comment option extensions.
        public enum Extension: VIZCodable, Equatable, Sendable {
            /// Unknown extension.
            case unknown
            /// Comment payout routing.
            case commentPayoutBeneficiaries([BeneficiaryRoute])
        }

        public var author: String
        public var permlink: String
        public var maxAcceptedPayout: Asset
        public var percentSteemDollars: UInt16
        public var allowVotes: Bool
        public var allowCurationRewards: Bool
        public var extensions: [Extension]

        public init(
            author: String,
            permlink: String,
            maxAcceptedPayout: Asset,
            percentSteemDollars: UInt16,
            allowVotes: Bool = true,
            allowCurationRewards: Bool = true,
            extensions: [Extension] = []
        ) {
            self.author = author
            self.permlink = permlink
            self.maxAcceptedPayout = maxAcceptedPayout
            self.percentSteemDollars = percentSteemDollars
            self.allowVotes = allowVotes
            self.allowCurationRewards = allowCurationRewards
            self.extensions = extensions
        }
    }

    /// Sets withdraw vesting route for account.
    public struct SetWithdrawVestingRoute: OperationType, Equatable {
        public var fromAccount: String
        public var toAccount: String
        public var percent: UInt16
        public var autoVest: Bool

        public init(
            fromAccount: String,
            toAccount: String,
            percent: UInt16,
            autoVest: Bool
        ) {
            self.fromAccount = fromAccount
            self.toAccount = toAccount
            self.percent = percent
            self.autoVest = autoVest
        }
    }

    public struct ChallengeAuthority: OperationType, Equatable {
        public var challenger: String
        public var challenged: String
        public var requireOwner: Bool

        public init(
            challenger: String,
            challenged: String,
            requireOwner: Bool
        ) {
            self.challenger = challenger
            self.challenged = challenged
            self.requireOwner = requireOwner
        }
    }

    public struct ProveAuthority: OperationType, Equatable {
        public var challenged: String
        public var requireOwner: Bool

        public init(
            challenged: String,
            requireOwner: Bool
        ) {
            self.challenged = challenged
            self.requireOwner = requireOwner
        }
    }

    public struct RequestAccountRecovery: OperationType, Equatable {
        public var recoveryAccount: String
        public var accountToRecover: String
        public var newOwnerAuthority: Authority
        public var extensions: [FutureExtensions]

        public init(
            recoveryAccount: String,
            accountToRecover: String,
            newOwnerAuthority: Authority,
            extensions: [FutureExtensions] = []
        ) {
            self.recoveryAccount = recoveryAccount
            self.accountToRecover = accountToRecover
            self.newOwnerAuthority = newOwnerAuthority
            self.extensions = extensions
        }
    }

    public struct RecoverAccount: OperationType, Equatable {
        public var accountToRecover: String
        public var newOwnerAuthority: Authority
        public var recentOwnerAuthority: Authority
        public var extensions: [FutureExtensions]

        public init(
            accountToRecover: String,
            newOwnerAuthority: Authority,
            recentOwnerAuthority: Authority,
            extensions: [FutureExtensions] = []
        ) {
            self.accountToRecover = accountToRecover
            self.newOwnerAuthority = newOwnerAuthority
            self.recentOwnerAuthority = recentOwnerAuthority
            self.extensions = extensions
        }
    }

    public struct ChangeRecoveryAccount: OperationType, Equatable {
        public var accountToRecover: String
        public var newRecoveryAccount: String
        public var extensions: [FutureExtensions]

        public init(
            accountToRecover: String,
            newRecoveryAccount: String,
            extensions: [FutureExtensions] = []
        ) {
            self.accountToRecover = accountToRecover
            self.newRecoveryAccount = newRecoveryAccount
            self.extensions = extensions
        }
    }

    public struct EscrowTransfer: OperationType, Equatable {
        public var from: String
        public var to: String
        public var agent: String
        public var escrowId: UInt32
        public var sbdAmount: Asset
        public var steemAmount: Asset
        public var fee: Asset
        public var ratificationDeadline: Date
        public var escrowExpiration: Date
        public var jsonMeta: JSONString

        public init(
            from: String,
            to: String,
            agent: String,
            escrowId: UInt32,
            sbdAmount: Asset,
            steemAmount: Asset,
            fee: Asset,
            ratificationDeadline: Date,
            escrowExpiration: Date,
            jsonMeta: JSONString = ""
        ) {
            self.from = from
            self.to = to
            self.agent = agent
            self.escrowId = escrowId
            self.sbdAmount = sbdAmount
            self.steemAmount = steemAmount
            self.fee = fee
            self.ratificationDeadline = ratificationDeadline
            self.escrowExpiration = escrowExpiration
            self.jsonMeta = jsonMeta
        }

        /// Metadata.
        var metadata: [String: Any]? {
            set { self.jsonMeta.object = newValue }
            get { return self.jsonMeta.object }
        }
    }

    public struct EscrowDispute: OperationType, Equatable {
        public var from: String
        public var to: String
        public var agent: String
        public var who: String
        public var escrowId: UInt32

        public init(
            from: String,
            to: String,
            agent: String,
            who: String,
            escrowId: UInt32
        ) {
            self.from = from
            self.to = to
            self.agent = agent
            self.who = who
            self.escrowId = escrowId
        }
    }

    public struct EscrowRelease: OperationType, Equatable {
        public var from: String
        public var to: String
        public var agent: String
        public var who: String
        public var receiver: String
        public var escrowId: UInt32
        public var sbdAmount: Asset
        public var steemAmount: Asset

        public init(
            from: String,
            to: String,
            agent: String,
            who: String,
            receiver: String,
            escrowId: UInt32,
            sbdAmount: Asset,
            steemAmount: Asset
        ) {
            self.from = from
            self.to = to
            self.agent = agent
            self.who = who
            self.receiver = receiver
            self.escrowId = escrowId
            self.sbdAmount = sbdAmount
            self.steemAmount = steemAmount
        }
    }

    public struct EscrowApprove: OperationType, Equatable {
        public var from: String
        public var to: String
        public var agent: String
        public var who: String
        public var escrowId: UInt32
        public var approve: Bool

        public init(
            from: String,
            to: String,
            agent: String,
            who: String,
            escrowId: UInt32,
            approve: Bool
        ) {
            self.from = from
            self.to = to
            self.agent = agent
            self.who = who
            self.escrowId = escrowId
            self.approve = approve
        }
    }

    public struct TransferToSavings: OperationType, Equatable {
        public var from: String
        public var to: String
        public var amount: Asset
        public var memo: String

        public init(
            from: String,
            to: String,
            amount: Asset,
            memo: String
        ) {
            self.from = from
            self.to = to
            self.amount = amount
            self.memo = memo
        }
    }

    public struct TransferFromSavings: OperationType, Equatable {
        public var from: String
        public var requestId: UInt32
        public var to: String
        public var amount: Asset
        public var memo: String

        public init(
            from: String,
            requestId: UInt32,
            to: String,
            amount: Asset,
            memo: String = ""
        ) {
            self.from = from
            self.requestId = requestId
            self.to = to
            self.amount = amount
            self.memo = memo
        }
    }

    public struct CancelTransferFromSavings: OperationType, Equatable {
        public var from: String
        public var requestId: UInt32

        public init(
            from: String,
            requestId: UInt32
        ) {
            self.from = from
            self.requestId = requestId
        }
    }

    public struct CustomBinary: OperationType, Equatable {
        public var requiredOwnerAuths: [String]
        public var requiredActiveAuths: [String]
        public var requiredPostingAuths: [String]
        public var requiredAuths: [Authority]
        public var id: String
        public var data: Data

        public init(
            requiredOwnerAuths: [String],
            requiredActiveAuths: [String],
            requiredPostingAuths: [String],
            requiredAuths: [Authority],
            id: String,
            data: Data
        ) {
            self.requiredOwnerAuths = requiredOwnerAuths
            self.requiredActiveAuths = requiredActiveAuths
            self.requiredPostingAuths = requiredPostingAuths
            self.requiredAuths = requiredAuths
            self.id = id
            self.data = data
        }
    }

    public struct DeclineVotingRights: OperationType, Equatable {
        public var account: String
        public var decline: Bool

        public init(
            account: String,
            decline: Bool
        ) {
            self.account = account
            self.decline = decline
        }
    }

    public struct ResetAccount: OperationType, Equatable {
        public var resetAccount: String
        public var accountToReset: String
        public var newOwnerAuthority: Authority

        public init(
            resetAccount: String,
            accountToReset: String,
            newOwnerAuthority: Authority
        ) {
            self.resetAccount = resetAccount
            self.accountToReset = accountToReset
            self.newOwnerAuthority = newOwnerAuthority
        }
    }

    public struct SetResetAccount: OperationType, Equatable {
        public var account: String
        public var currentResetAccount: String
        public var resetAccount: String

        public init(
            account: String,
            currentResetAccount: String,
            resetAccount: String
        ) {
            self.account = account
            self.currentResetAccount = currentResetAccount
            self.resetAccount = resetAccount
        }
    }

    public struct ClaimRewardBalance: OperationType, Equatable {
        public var account: String
        public var rewardSteem: Asset
        public var rewardSbd: Asset
        public var rewardVests: Asset

        public init(
            account: String,
            rewardSteem: Asset,
            rewardSbd: Asset,
            rewardVests: Asset
        ) {
            self.account = account
            self.rewardSteem = rewardSteem
            self.rewardSbd = rewardSbd
            self.rewardVests = rewardVests
        }
    }

    public struct DelegateVestingShares: OperationType, Equatable {
        public var delegator: String
        public var delegatee: String
        public var vestingShares: Asset

        public init(
            delegator: String,
            delegatee: String,
            vestingShares: Asset
        ) {
            self.delegator = delegator
            self.delegatee = delegatee
            self.vestingShares = vestingShares
        }
    }

    public struct AccountCreateWithDelegation: OperationType, Equatable {
        public var fee: Asset
        public var delegation: Asset
        public var creator: String
        public var newAccountName: String
        public var master: Authority
        public var active: Authority
        public var regular: Authority
        public var memoKey: PublicKey
        public var jsonMetadata: JSONString
        public var extensions: [FutureExtensions]

        public init(
            fee: Asset,
            delegation: Asset,
            creator: String,
            newAccountName: String,
            master: Authority,
            active: Authority,
            regular: Authority,
            memoKey: PublicKey,
            jsonMetadata: JSONString = "",
            extensions: [FutureExtensions] = []
        ) {
            self.fee = fee
            self.delegation = delegation
            self.creator = creator
            self.newAccountName = newAccountName
            self.master = master
            self.active = active
            self.regular = regular
            self.memoKey = memoKey
            self.jsonMetadata = jsonMetadata
            self.extensions = extensions
        }

        /// Account metadata.
        var metadata: [String: Any]? {
            set { self.jsonMetadata.object = newValue }
            get { return self.jsonMetadata.object }
        }
    }
    
    public struct Award: OperationType, Equatable {
        public let initiator: String
        public let receiver: String
        public let energy: UInt16
        public let customSequence: UInt64
        public let memo: String
        public let beneficiaries: [Beneficiary]
        
        public init(initiator: String, receiver: String, energy: UInt16, customSequence: UInt64, memo: String, beneficiaries: [Operation.Beneficiary]) {
            self.initiator = initiator
            self.receiver = receiver
            self.energy = energy
            self.customSequence = customSequence
            self.memo = memo
            self.beneficiaries = beneficiaries
        }
    }
    
    public struct Beneficiary: OperationType, Equatable {
        public let account: String
        public let weight: UInt16
        
        public init(account: String, weight: UInt16) {
            self.account = account
            self.weight = weight
        }
    }
    
    public struct InviteRegistration: OperationType, Equatable {
        public let initiator: String
        public let newAccountName: String
        public let inviteSecret: String
        public let newAccountKey: PublicKey
        
        public init(initiator: String, newAccountName: String, inviteSecret: String, newAccountKey: PublicKey) {
            self.initiator = initiator
            self.newAccountName = newAccountName
            self.inviteSecret = inviteSecret
            self.newAccountKey = newAccountKey
        }
    }

    // Virtual operations.
    
    public struct ReceiveAward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let initiator: String
        public let receiver: String
        public let customSequence: UInt64
        public let memo: String
        public let shares: Asset
    }

    public struct AuthorReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let author: String
        public let permlink: String
        public let sbdPayout: Asset
        public let steemPayout: Asset
        public let vestingPayout: Asset
    }

    public struct CurationReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let curator: String
        public let reward: Asset
        public let commentAuthor: String
        public let commentPermlink: String
    }

    public struct CommentReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let author: String
        public let permlink: String
        public let payout: Asset
    }

    public struct LiquidityReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let owner: String
        public let payout: Asset
    }

    public struct Interest: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let owner: String
        public let interest: Asset
    }

    public struct FillConvertRequest: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let owner: String
        public let requestid: UInt32
        public let amountIn: Asset
        public let amountOut: Asset
    }

    public struct FillVestingWithdraw: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let fromAccount: String
        public let toAccount: String
        public let withdrawn: Asset
        public let deposited: Asset
    }

    public struct ShutdownValidator: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let owner: String
    }

    public struct FillOrder: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let currentOwner: String
        public let currentOrderid: UInt32
        public let currentPays: Asset
        public let openOwner: String
        public let openOrderid: UInt32
        public let openPays: Asset
    }

    public struct FillTransferFromSavings: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let from: String
        public let to: String
        public let amount: Asset
        public let requestId: UInt32
        public let memo: String
    }

    public struct Hardfork: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let hardforkId: UInt32
    }

    public struct CommentPayoutUpdate: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let author: String
        public let permlink: String
    }

    public struct ReturnVestingDelegation: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let vestingShares: Asset
    }

    public struct BenefactorAward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let initiator: String
        public let benefactor: String
        public let receiver: String
        public let customSequence: UInt64
        public let memo: String
        public let shares: Asset
    }

    public struct ValidatorReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let validator: String
        public let shares: Asset

        public init(validator: String, shares: Asset) {
            self.validator = validator
            self.shares = shares
        }

        @available(*, deprecated, message: "Use init(validator:shares:)")
        public init(witness: String, shares: Asset) {
            self.init(validator: witness, shares: shares)
        }

        @available(*, deprecated, renamed: "validator")
        public var witness: String { validator }

        enum CodingKeys: String, CodingKey {
            case validator, shares
            case legacyWitness = "witness"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.shares = try c.decode(Asset.self, forKey: .shares)
            self.validator = try (try? c.decode(String.self, forKey: .validator))
                          ?? c.decode(String.self, forKey: .legacyWitness)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(validator, forKey: .validator)
            try c.encode(shares,    forKey: .shares)
        }
    }


    // MARK: HF13

    /// `fixed_award` (op 60).
    public struct FixedAward: OperationType, Equatable {
        public var initiator: String
        public var receiver: String
        public var rewardAmount: Asset
        public var maxEnergy: UInt16
        public var customSequence: UInt64
        public var memo: String
        public var beneficiaries: [Beneficiary]

        public init(
            initiator: String,
            receiver: String,
            rewardAmount: Asset,
            maxEnergy: UInt16,
            customSequence: UInt64 = 0,
            memo: String = "",
            beneficiaries: [Beneficiary] = []
        ) {
            self.initiator = initiator
            self.receiver = receiver
            self.rewardAmount = rewardAmount
            self.maxEnergy = maxEnergy
            self.customSequence = customSequence
            self.memo = memo
            self.beneficiaries = beneficiaries
        }
    }

    /// `target_account_sale` (op 61).
    public struct TargetAccountSale: OperationType, Equatable {
        public var account: String
        public var accountSeller: String
        public var targetBuyer: String
        public var accountOfferPrice: Asset
        public var accountOnSale: Bool

        public init(
            account: String,
            accountSeller: String,
            targetBuyer: String,
            accountOfferPrice: Asset,
            accountOnSale: Bool
        ) {
            self.account = account
            self.accountSeller = accountSeller
            self.targetBuyer = targetBuyer
            self.accountOfferPrice = accountOfferPrice
            self.accountOnSale = accountOnSale
        }
    }


    // MARK: HF13 (virtual)

    /// `bid` (op 62).
    public struct Bid: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let bidder: String
        public let bid: Asset
    }

    /// `outbid` (op 63).
    public struct Outbid: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let bidder: String
        public let bid: Asset
    }

    /// `set_reward_sharing` (op 64).
    public struct SetRewardSharing: OperationType, Equatable {
        public var owner: String
        public var sharingRate: UInt16

        public init(
            owner: String,
            sharingRate: UInt16
        ) {
            self.owner = owner
            self.sharingRate = sharingRate
        }
    }

    /// `stakeholder_reward` (op 65).
    public struct StakeholderReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let validator: String
        public let stakeholder: String
        public let shares: Asset
    }


    // MARK: HF14 prediction markets (Onix)

    /// `pm_oracle_register` (op 66).
    public struct PmOracleRegister: OperationType, Equatable {
        public var owner: String
        public var insurance: Asset
        public var feePercent: UInt16
        public var fixedFee: Asset
        public var rulesUrl: String
        public var autoAcceptCreator: String
        public var autoAcceptResolver: String
        public var autoAccept: Bool
        public var extensions: [FutureExtensions]

        public init(
            owner: String,
            insurance: Asset,
            feePercent: UInt16,
            fixedFee: Asset,
            rulesUrl: String,
            autoAcceptCreator: String,
            autoAcceptResolver: String,
            autoAccept: Bool,
            extensions: [FutureExtensions] = []
        ) {
            self.owner = owner
            self.insurance = insurance
            self.feePercent = feePercent
            self.fixedFee = fixedFee
            self.rulesUrl = rulesUrl
            self.autoAcceptCreator = autoAcceptCreator
            self.autoAcceptResolver = autoAcceptResolver
            self.autoAccept = autoAccept
            self.extensions = extensions
        }
    }

    /// `pm_oracle_update` (op 67).
    public struct PmOracleUpdate: OperationType, Equatable {
        public var owner: String
        public var insuranceDelta: Asset?
        public var feePercent: UInt16?
        public var fixedFee: Asset?
        public var rulesUrl: String?
        public var autoAcceptCreator: String?
        public var autoAcceptResolver: String?
        public var autoAccept: Bool?
        public var extensions: [FutureExtensions]

        public init(
            owner: String,
            insuranceDelta: Asset? = nil,
            feePercent: UInt16? = nil,
            fixedFee: Asset? = nil,
            rulesUrl: String? = nil,
            autoAcceptCreator: String? = nil,
            autoAcceptResolver: String? = nil,
            autoAccept: Bool? = nil,
            extensions: [FutureExtensions] = []
        ) {
            self.owner = owner
            self.insuranceDelta = insuranceDelta
            self.feePercent = feePercent
            self.fixedFee = fixedFee
            self.rulesUrl = rulesUrl
            self.autoAcceptCreator = autoAcceptCreator
            self.autoAcceptResolver = autoAcceptResolver
            self.autoAccept = autoAccept
            self.extensions = extensions
        }

        // Synthesized Codable uses encodeIfPresent, which drops the optional flag byte;
        // write the fields explicitly so `nil` → 0x00 and `value` → 0x01 + value.
        public func binaryEncode(to encoder: VIZEncoder) throws {
            try encoder.encode(owner)
            try encoder.encode(insuranceDelta)
            try encoder.encode(feePercent)
            try encoder.encode(fixedFee)
            try encoder.encode(rulesUrl)
            try encoder.encode(autoAcceptCreator)
            try encoder.encode(autoAcceptResolver)
            try encoder.encode(autoAccept)
            try encoder.encode(extensions)
        }
    }

    /// `pm_create_market` (op 68).
    public struct PmCreateMarket: OperationType, Equatable {
        public var creator: String
        public var oracle: String
        public var marketType: UInt8
        public var outcomes: [String]  // order preserved on the wire
        public var url: String
        public var oracleFeePercent: UInt16
        public var oracleFixedFee: Asset
        public var creatorFeePercent: UInt16
        public var liquidityFeePercent: UInt16
        public var liquidity: Asset
        public var lmsrB: Int64
        public var bettingExpiration: Date
        public var resultExpiration: Date
        public var timePenaltyType: UInt8
        public var timePenaltyValue: UInt32
        public var penaltyCurveType: UInt8
        public var allowEarlyResolution: Bool
        public var allowCancellation: Bool
        public var allowBatch: Bool
        public var allowInstantBet: Bool
        public var endogeneityTier: UInt8
        public var disputeMode: UInt8
        public var disputeResolver: String
        public var disputePenaltyPercent: Int16
        public var metadata: String
        public var extensions: [FutureExtensions]

        public init(
            creator: String,
            oracle: String,
            marketType: UInt8,
            outcomes: [String],
            url: String,
            oracleFeePercent: UInt16,
            oracleFixedFee: Asset,
            creatorFeePercent: UInt16,
            liquidityFeePercent: UInt16,
            liquidity: Asset,
            lmsrB: Int64,
            bettingExpiration: Date,
            resultExpiration: Date,
            timePenaltyType: UInt8,
            timePenaltyValue: UInt32,
            penaltyCurveType: UInt8,
            allowEarlyResolution: Bool,
            allowCancellation: Bool,
            allowBatch: Bool,
            allowInstantBet: Bool = true,
            endogeneityTier: UInt8 = 2,
            disputeMode: UInt8,
            disputeResolver: String,
            disputePenaltyPercent: Int16,
            metadata: String,
            extensions: [FutureExtensions] = []
        ) {
            self.creator = creator
            self.oracle = oracle
            self.marketType = marketType
            self.outcomes = outcomes
            self.url = url
            self.oracleFeePercent = oracleFeePercent
            self.oracleFixedFee = oracleFixedFee
            self.creatorFeePercent = creatorFeePercent
            self.liquidityFeePercent = liquidityFeePercent
            self.liquidity = liquidity
            self.lmsrB = lmsrB
            self.bettingExpiration = bettingExpiration
            self.resultExpiration = resultExpiration
            self.timePenaltyType = timePenaltyType
            self.timePenaltyValue = timePenaltyValue
            self.penaltyCurveType = penaltyCurveType
            self.allowEarlyResolution = allowEarlyResolution
            self.allowCancellation = allowCancellation
            self.allowBatch = allowBatch
            self.allowInstantBet = allowInstantBet
            self.endogeneityTier = endogeneityTier
            self.disputeMode = disputeMode
            self.disputeResolver = disputeResolver
            self.disputePenaltyPercent = disputePenaltyPercent
            self.metadata = metadata
            self.extensions = extensions
        }
    }

    /// `pm_oracle_accept_market` (op 69).
    public struct PmOracleAcceptMarket: OperationType, Equatable {
        public var oracle: String
        public var marketId: Int64
        public var accept: Bool
        public var oracleFeePercent: UInt16
        public var oracleFixedFee: Asset
        public var extensions: [FutureExtensions]

        public init(
            oracle: String,
            marketId: Int64,
            accept: Bool,
            oracleFeePercent: UInt16,
            oracleFixedFee: Asset,
            extensions: [FutureExtensions] = []
        ) {
            self.oracle = oracle
            self.marketId = marketId
            self.accept = accept
            self.oracleFeePercent = oracleFeePercent
            self.oracleFixedFee = oracleFixedFee
            self.extensions = extensions
        }
    }

    /// `pm_place_bet` (op 70).
    public struct PmPlaceBet: OperationType, Equatable {
        public var account: String
        public var marketId: Int64
        public var side: Int8
        public var outcomeIndex: Int16
        public var amount: Asset
        public var minTokens: Int64
        public var mode: UInt8
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            marketId: Int64,
            side: Int8 = -1,
            outcomeIndex: Int16 = -1,
            amount: Asset,
            minTokens: Int64 = 0,
            mode: UInt8 = 0,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.marketId = marketId
            self.side = side
            self.outcomeIndex = outcomeIndex
            self.amount = amount
            self.minTokens = minTokens
            self.mode = mode
            self.extensions = extensions
        }
    }

    /// `pm_commit_bet` (op 71).
    public struct PmCommitBet: OperationType, Equatable {
        public var account: String
        public var marketId: Int64
        public var commitment: Data  // sha256, 32 bytes
        public var escrowAmount: Asset
        public var noRevealFeePercent: UInt16
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            marketId: Int64,
            commitment: Data,
            escrowAmount: Asset,
            noRevealFeePercent: UInt16,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.marketId = marketId
            self.commitment = commitment
            self.escrowAmount = escrowAmount
            self.noRevealFeePercent = noRevealFeePercent
            self.extensions = extensions
        }
    }

    /// `pm_reveal_bet` (op 72).
    public struct PmRevealBet: OperationType, Equatable {
        public var account: String
        public var commitId: Int64
        public var side: Int8
        public var outcomeIndex: Int16
        public var amount: Asset
        public var salt: String
        public var minTokens: Int64
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            commitId: Int64,
            side: Int8 = -1,
            outcomeIndex: Int16 = -1,
            amount: Asset,
            salt: String,
            minTokens: Int64 = 0,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.commitId = commitId
            self.side = side
            self.outcomeIndex = outcomeIndex
            self.amount = amount
            self.salt = salt
            self.minTokens = minTokens
            self.extensions = extensions
        }
    }

    /// `pm_cancel_bet` (op 73).
    public struct PmCancelBet: OperationType, Equatable {
        public var account: String
        public var betId: Int64
        public var minReturn: Int64
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            betId: Int64,
            minReturn: Int64,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.betId = betId
            self.minReturn = minReturn
            self.extensions = extensions
        }
    }

    /// `pm_add_liquidity` (op 74).
    public struct PmAddLiquidity: OperationType, Equatable {
        public var provider: String
        public var marketId: Int64
        public var amount: Asset
        public var extensions: [FutureExtensions]

        public init(
            provider: String,
            marketId: Int64,
            amount: Asset,
            extensions: [FutureExtensions] = []
        ) {
            self.provider = provider
            self.marketId = marketId
            self.amount = amount
            self.extensions = extensions
        }
    }

    /// `pm_withdraw_liquidity` (op 75).
    public struct PmWithdrawLiquidity: OperationType, Equatable {
        public var provider: String
        public var liquidityId: Int64
        public var amount: Asset
        public var extensions: [FutureExtensions]

        public init(
            provider: String,
            liquidityId: Int64,
            amount: Asset,
            extensions: [FutureExtensions] = []
        ) {
            self.provider = provider
            self.liquidityId = liquidityId
            self.amount = amount
            self.extensions = extensions
        }
    }

    /// `pm_resolve_market` (op 76).
    public struct PmResolveMarket: OperationType, Equatable {
        public var oracle: String
        public var marketId: Int64
        public var winningOutcome: Int16
        public var decisionUrl: String
        public var decisionReason: String
        public var extensions: [FutureExtensions]

        public init(
            oracle: String,
            marketId: Int64,
            winningOutcome: Int16,
            decisionUrl: String,
            decisionReason: String,
            extensions: [FutureExtensions] = []
        ) {
            self.oracle = oracle
            self.marketId = marketId
            self.winningOutcome = winningOutcome
            self.decisionUrl = decisionUrl
            self.decisionReason = decisionReason
            self.extensions = extensions
        }
    }

    /// `pm_no_contest` (op 77).
    public struct PmNoContest: OperationType, Equatable {
        public var oracle: String
        public var marketId: Int64
        public var reason: String
        public var extensions: [FutureExtensions]

        public init(
            oracle: String,
            marketId: Int64,
            reason: String,
            extensions: [FutureExtensions] = []
        ) {
            self.oracle = oracle
            self.marketId = marketId
            self.reason = reason
            self.extensions = extensions
        }
    }

    /// `pm_dispute_create` (op 78).
    public struct PmDisputeCreate: OperationType, Equatable {
        public var disputer: String
        public var marketId: Int64
        public var proposedOutcome: Int16
        public var reason: String
        public var extensions: [FutureExtensions]

        public init(
            disputer: String,
            marketId: Int64,
            proposedOutcome: Int16,
            reason: String,
            extensions: [FutureExtensions] = []
        ) {
            self.disputer = disputer
            self.marketId = marketId
            self.proposedOutcome = proposedOutcome
            self.reason = reason
            self.extensions = extensions
        }
    }

    /// `pm_dispute_vote` (op 79).
    public struct PmDisputeVote: OperationType, Equatable {
        public var voter: String
        public var marketId: Int64
        public var voteOutcome: Int16
        public var votePercent: Int16
        public var extensions: [FutureExtensions]

        public init(
            voter: String,
            marketId: Int64,
            voteOutcome: Int16,
            votePercent: Int16,
            extensions: [FutureExtensions] = []
        ) {
            self.voter = voter
            self.marketId = marketId
            self.voteOutcome = voteOutcome
            self.votePercent = votePercent
            self.extensions = extensions
        }
    }

    /// `pm_dispute_resolve` (op 80).
    public struct PmDisputeResolve: OperationType, Equatable {
        public var resolver: String
        public var marketId: Int64
        public var correctOutcome: Int16
        public var penaltyAmount: Asset
        public var banOracle: Bool
        public var banOracleUntil: Date
        public var banCreator: Bool
        public var banCreatorUntil: Date
        public var extensions: [FutureExtensions]

        public init(
            resolver: String,
            marketId: Int64,
            correctOutcome: Int16,
            penaltyAmount: Asset,
            banOracle: Bool,
            banOracleUntil: Date,
            banCreator: Bool,
            banCreatorUntil: Date,
            extensions: [FutureExtensions] = []
        ) {
            self.resolver = resolver
            self.marketId = marketId
            self.correctOutcome = correctOutcome
            self.penaltyAmount = penaltyAmount
            self.banOracle = banOracle
            self.banOracleUntil = banOracleUntil
            self.banCreator = banCreator
            self.banCreatorUntil = banCreatorUntil
            self.extensions = extensions
        }
    }

    /// `pm_transfer_position` (op 81).
    public struct PmTransferPosition: OperationType, Equatable {
        public var from: String
        public var betId: Int64
        public var to: String
        public var amount: Int64  // share weight (int64), not an Asset
        public var memo: String
        public var extensions: [FutureExtensions]

        public init(
            from: String,
            betId: Int64,
            to: String,
            amount: Int64,
            memo: String = "",
            extensions: [FutureExtensions] = []
        ) {
            self.from = from
            self.betId = betId
            self.to = to
            self.amount = amount
            self.memo = memo
            self.extensions = extensions
        }
    }

    /// `pm_lazy_deposit` (op 82).
    public struct PmLazyDeposit: OperationType, Equatable {
        public var account: String
        public var amount: Asset
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            amount: Asset,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.amount = amount
            self.extensions = extensions
        }
    }

    /// `pm_lazy_withdraw` (op 83).
    public struct PmLazyWithdraw: OperationType, Equatable {
        public var account: String
        public var shares: Int64
        public var emergency: Bool
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            shares: Int64,
            emergency: Bool,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.shares = shares
            self.emergency = emergency
            self.extensions = extensions
        }
    }


    // MARK: HF14 prediction-market virtual operations (decode-only)

    /// `pm_batch_settle` (op 84).
    public struct PmBatchSettle: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let marketId: Int64
        public let epoch: UInt32
        public let settledBets: UInt32
    }

    /// `pm_commit_forfeit` (op 85).
    public struct PmCommitForfeit: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let commitId: Int64
        public let marketId: Int64
        public let penalty: Asset
        public let refund: Asset
    }

    /// `pm_auto_payout` (op 86).
    public struct PmAutoPayout: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let marketId: Int64
        public let betId: Int64
        public let payout: Asset
    }

    /// `pm_dispute_finalize` (op 87).
    public struct PmDisputeFinalize: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let marketId: Int64
        public let winningOutcome: Int16
        public let oraclePenalty: Asset
    }

    /// `pm_dispute_auto_close` (op 88).
    public struct PmDisputeAutoClose: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let marketId: Int64
        public let oraclePenalty: Asset
    }

    /// `pm_oracle_missed_penalty` (op 89).
    public struct PmOracleMissedPenalty: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let marketId: Int64
        public let slashed: Asset
    }

    /// `pm_lazy_recall` (op 90).
    public struct PmLazyRecall: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let marketId: Int64
        public let recalled: Asset
    }

    /// `pm_leverage_open` (op 91).
    public struct PmLeverageOpen: OperationType, Equatable {
        public var account: String
        public var marketId: Int64
        public var outcomeIndex: Int16
        public var collateral: Asset
        public var loan: Asset
        public var minTokens: Int64
        public var maxSlippagePercent: UInt16
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            marketId: Int64,
            outcomeIndex: Int16 = -1,
            collateral: Asset,
            loan: Asset,
            minTokens: Int64 = 0,
            maxSlippagePercent: UInt16,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.marketId = marketId
            self.outcomeIndex = outcomeIndex
            self.collateral = collateral
            self.loan = loan
            self.minTokens = minTokens
            self.maxSlippagePercent = maxSlippagePercent
            self.extensions = extensions
        }
    }

    /// `pm_leverage_close` (op 92).
    public struct PmLeverageClose: OperationType, Equatable {
        public var account: String
        public var positionId: Int64
        public var minReturn: Int64
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            positionId: Int64,
            minReturn: Int64,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.positionId = positionId
            self.minReturn = minReturn
            self.extensions = extensions
        }
    }

    /// `pm_leverage_convert` (op 93).
    public struct PmLeverageConvert: OperationType, Equatable {
        public var account: String
        public var positionId: Int64
        public var conversionProfitCost: UInt16
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            positionId: Int64,
            conversionProfitCost: UInt16,
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.positionId = positionId
            self.conversionProfitCost = conversionProfitCost
            self.extensions = extensions
        }
    }

    /// `pm_leverage_liquidate` (op 94).
    public struct PmLeverageLiquidate: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let positionId: Int64
        public let marketId: Int64
        public let cancelValue: Asset
        public let poolReceived: Asset
        public let bettorReceived: Asset
        public let reason: UInt8
    }

    /// `pm_leverage_resolve` (op 95).
    public struct PmLeverageResolve: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let positionId: Int64
        public let marketId: Int64
        public let won: Bool
        public let poolReceived: Asset
        public let bettorReceived: Asset
        public let outcomeIndex: Int16
        public let leverage: UInt16
    }

    /// `pm_market_accepted` (op 96).
    public struct PmMarketAccepted: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let creator: String
        public let marketId: Int64
        public let oracleFeePercent: UInt16
        public let oracleFixedFee: Asset
        public let selfOracle: Bool
    }

    /// `pm_payout` (op 97).
    public struct PmPayout: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let marketId: Int64
        public let betId: Int64
        public let side: Int8
        public let outcomeIndex: Int16
        public let amount: Asset
        public let payout: Asset
    }

    /// `pm_dispute_oracle_respond` (op 98).
    public struct PmDisputeOracleRespond: OperationType, Equatable {
        public var oracle: String
        public var marketId: Int64
        public var response: String
        public var extensions: [FutureExtensions]

        public init(
            oracle: String,
            marketId: Int64,
            response: String,
            extensions: [FutureExtensions] = []
        ) {
            self.oracle = oracle
            self.marketId = marketId
            self.response = response
            self.extensions = extensions
        }
    }

    /// `pm_unban` (op 99).
    public struct PmUnban: OperationType, Equatable {
        public var resolver: String
        public var target: String
        public var unbanOracle: Bool
        public var unbanCreator: Bool
        public var extensions: [FutureExtensions]

        public init(
            resolver: String,
            target: String,
            unbanOracle: Bool,
            unbanCreator: Bool,
            extensions: [FutureExtensions] = []
        ) {
            self.resolver = resolver
            self.target = target
            self.unbanOracle = unbanOracle
            self.unbanCreator = unbanCreator
            self.extensions = extensions
        }
    }

    /// `pm_ban_expired` (op 100).
    public struct PmBanExpired: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let oracle: Bool
        public let creator: Bool
    }

    /// `pm_market_expired` (op 101).
    public struct PmMarketExpired: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let creator: String
        public let marketId: Int64
        public let refundedLiquidity: Asset
    }

    /// `pm_dispute_opened` (op 102).
    public struct PmDisputeOpened: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let oracle: String
        public let disputer: String
        public let marketId: Int64
        public let proposedOutcome: Int16
    }

    /// `pm_early_exit_claim_paid` (op 103).
    public struct PmEarlyExitClaimPaid: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let marketId: Int64
        public let kind: UInt8
        public let outcomeIndex: UInt8
        public let claimed: Asset
        public let paid: Asset
    }

    /// `pm_lp_payout` (op 104).
    public struct PmLpPayout: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let account: String
        public let marketId: Int64
        public let principal: Asset
        public let income: Asset
        public let charge: Asset
    }


    // MARK: HF15

    /// `set_agent_permission` (op 105).
    public struct SetAgentPermission: OperationType, Equatable {
        public var account: String
        public var agentName: String
        public var agentKey: PublicKey
        public var operations: [String]  // flat_set: pass sorted
        public var expiration: Date
        public var addons: [String]  // flat_set: pass sorted
        public var extensions: [FutureExtensions]

        public init(
            account: String,
            agentName: String,
            agentKey: PublicKey,
            operations: [String],
            expiration: Date,
            addons: [String] = [],
            extensions: [FutureExtensions] = []
        ) {
            self.account = account
            self.agentName = agentName
            self.agentKey = agentKey
            self.operations = operations
            self.expiration = expiration
            self.addons = addons
            self.extensions = extensions
        }
    }

    /// Unknown operation, seen if the decoder encounters operation which has no type defined.
    /// - Note: Not encodable, the encoder will throw if encountering this operation.
    public struct Unknown: OperationType, Equatable {}
}

// MARK: - Encoding

/// Operation ID, used for coding.
fileprivate enum OperationId: UInt8, VIZEncodable, Decodable {
    case vote = 0
    case content = 1
    case transfer = 2
    case transfer_to_vesting = 3
    case withdraw_vesting = 4
    case account_update = 5
    case validator_update = 6
    case account_validator_vote = 7
    case account_validator_proxy = 8
    case delete_content = 9
    case custom = 10
    case set_withdraw_vesting_route = 11
    case request_account_recovery = 12
    case recover_account = 13
    case change_recovery_account = 14
    case escrow_transfer = 15
    case escrow_dispute = 16
    case escrow_release = 17
    case escrow_approve = 18
    case delegate_vesting_shares = 19
    case account_create = 20
    case account_metadata = 21
    case proposal_create = 22
    case proposal_update = 23
    case proposal_delete = 24
    case chain_properties_update = 25
    case author_reward = 26
    case curation_reward = 27
    case content_reward = 28
    case fill_vesting_withdraw = 29
    case shutdown_validator = 30
    case hardfork = 31
    case content_payout_update = 32
    case content_benefactor_reward = 33
    case return_vesting_delegation = 34
    case committee_worker_create_request = 35
    case committee_worker_cancel_request = 36
    case committee_vote_request = 37
    case committee_cancel_request = 38
    case committee_approve_request = 39
    case committee_payout_request = 40
    case committee_pay_request = 41
    case validator_reward = 42
    case create_invite = 43
    case claim_invite_balance = 44
    case invite_registration = 45
    case versioned_chain_properties_update = 46
    case award = 47
    case receive_award = 48
    case benefactor_award = 49
    case set_paid_subscription = 50
    case paid_subscribe = 51
    case paid_subscription_action = 52
    case cancel_paid_subscription = 53
    case set_account_price = 54
    case set_subaccount_price = 55
    case buy_account = 56
    case account_sale = 57
    case use_invite_balance = 58
    case expire_escrow_ratification = 59
    case fixed_award = 60
    case target_account_sale = 61
    case bid = 62
    case outbid = 63
    case set_reward_sharing = 64
    case stakeholder_reward = 65
    case pm_oracle_register = 66
    case pm_oracle_update = 67
    case pm_create_market = 68
    case pm_oracle_accept_market = 69
    case pm_place_bet = 70
    case pm_commit_bet = 71
    case pm_reveal_bet = 72
    case pm_cancel_bet = 73
    case pm_add_liquidity = 74
    case pm_withdraw_liquidity = 75
    case pm_resolve_market = 76
    case pm_no_contest = 77
    case pm_dispute_create = 78
    case pm_dispute_vote = 79
    case pm_dispute_resolve = 80
    case pm_transfer_position = 81
    case pm_lazy_deposit = 82
    case pm_lazy_withdraw = 83
    case pm_batch_settle = 84
    case pm_commit_forfeit = 85
    case pm_auto_payout = 86
    case pm_dispute_finalize = 87
    case pm_dispute_auto_close = 88
    case pm_oracle_missed_penalty = 89
    case pm_lazy_recall = 90
    case pm_leverage_open = 91
    case pm_leverage_close = 92
    case pm_leverage_convert = 93
    case pm_leverage_liquidate = 94
    case pm_leverage_resolve = 95
    case pm_market_accepted = 96
    case pm_payout = 97
    case pm_dispute_oracle_respond = 98
    case pm_unban = 99
    case pm_ban_expired = 100
    case pm_market_expired = 101
    case pm_dispute_opened = 102
    case pm_early_exit_claim_paid = 103
    case pm_lp_payout = 104
    case set_agent_permission = 105
    case unknown = 255

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        switch name {
        case "vote": self = .vote
        case "content": self = .content
        case "transfer": self = .transfer
        case "transfer_to_vesting": self = .transfer_to_vesting
        case "withdraw_vesting": self = .withdraw_vesting
        case "account_create": self = .account_create
        case "account_update": self = .account_update
        case "witness_update", "validator_update": self = .validator_update
        case "account_witness_vote", "account_validator_vote": self = .account_validator_vote
        case "account_witness_proxy", "account_validator_proxy": self = .account_validator_proxy
        case "custom": self = .custom
        case "set_withdraw_vesting_route": self = .set_withdraw_vesting_route
        case "request_account_recovery": self = .request_account_recovery
        case "recover_account": self = .recover_account
        case "change_recovery_account": self = .change_recovery_account
        case "escrow_transfer": self = .escrow_transfer
        case "escrow_dispute": self = .escrow_dispute
        case "escrow_release": self = .escrow_release
        case "escrow_approve": self = .escrow_approve
        case "delegate_vesting_shares": self = .delegate_vesting_shares
        case "author_reward": self = .author_reward
        case "curation_reward": self = .curation_reward
        case "fill_vesting_withdraw": self = .fill_vesting_withdraw
        case "shutdown_witness", "shutdown_validator": self = .shutdown_validator
        case "hardfork": self = .hardfork
        case "return_vesting_delegation": self = .return_vesting_delegation
        case "witness_reward", "validator_reward": self = .validator_reward
        case "create_invite": self = .create_invite
        case "claim_invite_balance": self = .claim_invite_balance
        case "invite_registration": self = .invite_registration
        case "versioned_chain_properties_update": self = .versioned_chain_properties_update
        case "award": self = .award
        case "receive_award": self = .receive_award //Virtual Operation
        case "benefactor_award": self = .benefactor_award //Virtual Operation
        case "set_paid_subscription": self = .set_paid_subscription
        case "paid_subscribe": self = .paid_subscribe
        case "paid_subscription_action": self = .paid_subscription_action //Virtual Operation
        case "cancel_paid_subscription": self = .cancel_paid_subscription //Virtual Operation
        case "set_account_price": self = .set_account_price
        case "set_subaccount_price": self = .set_subaccount_price
        case "buy_account": self = .buy_account
        case "account_sale": self = .account_sale //Virtual Operation
        case "fixed_award": self = .fixed_award
        case "target_account_sale": self = .target_account_sale
        case "bid": self = .bid
        case "outbid": self = .outbid
        case "set_reward_sharing": self = .set_reward_sharing
        case "stakeholder_reward": self = .stakeholder_reward
        case "pm_oracle_register": self = .pm_oracle_register
        case "pm_oracle_update": self = .pm_oracle_update
        case "pm_create_market": self = .pm_create_market
        case "pm_oracle_accept_market": self = .pm_oracle_accept_market
        case "pm_place_bet": self = .pm_place_bet
        case "pm_commit_bet": self = .pm_commit_bet
        case "pm_reveal_bet": self = .pm_reveal_bet
        case "pm_cancel_bet": self = .pm_cancel_bet
        case "pm_add_liquidity": self = .pm_add_liquidity
        case "pm_withdraw_liquidity": self = .pm_withdraw_liquidity
        case "pm_resolve_market": self = .pm_resolve_market
        case "pm_no_contest": self = .pm_no_contest
        case "pm_dispute_create": self = .pm_dispute_create
        case "pm_dispute_vote": self = .pm_dispute_vote
        case "pm_dispute_resolve": self = .pm_dispute_resolve
        case "pm_transfer_position": self = .pm_transfer_position
        case "pm_lazy_deposit": self = .pm_lazy_deposit
        case "pm_lazy_withdraw": self = .pm_lazy_withdraw
        case "pm_batch_settle": self = .pm_batch_settle
        case "pm_commit_forfeit": self = .pm_commit_forfeit
        case "pm_auto_payout": self = .pm_auto_payout
        case "pm_dispute_finalize": self = .pm_dispute_finalize
        case "pm_dispute_auto_close": self = .pm_dispute_auto_close
        case "pm_oracle_missed_penalty": self = .pm_oracle_missed_penalty
        case "pm_lazy_recall": self = .pm_lazy_recall
        case "pm_leverage_open": self = .pm_leverage_open
        case "pm_leverage_close": self = .pm_leverage_close
        case "pm_leverage_convert": self = .pm_leverage_convert
        case "pm_leverage_liquidate": self = .pm_leverage_liquidate
        case "pm_leverage_resolve": self = .pm_leverage_resolve
        case "pm_market_accepted": self = .pm_market_accepted
        case "pm_payout": self = .pm_payout
        case "pm_dispute_oracle_respond": self = .pm_dispute_oracle_respond
        case "pm_unban": self = .pm_unban
        case "pm_ban_expired": self = .pm_ban_expired
        case "pm_market_expired": self = .pm_market_expired
        case "pm_dispute_opened": self = .pm_dispute_opened
        case "pm_early_exit_claim_paid": self = .pm_early_exit_claim_paid
        case "pm_lp_payout": self = .pm_lp_payout
        case "set_agent_permission": self = .set_agent_permission
        default: self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(self)")
    }

    func binaryEncode(to encoder: VIZEncoder) throws {
        try encoder.encode(self.rawValue)
    }
}

/// A type-erased VIZ operation.
internal struct AnyOperation: VIZEncodable, Decodable, Sendable {
    public let operation: OperationType

    /// Create a new operation wrapper.
    public init<O>(_ operation: O) where O: OperationType {
        self.operation = operation
    }

    public init(_ operation: OperationType) {
        self.operation = operation
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let id = try container.decode(OperationId.self)
        let op: OperationType
        switch id {
        case .vote: op = try container.decode(Operation.Vote.self)
        case .content: op = try container.decode(Operation.Content.self)
        case .transfer: op = try container.decode(Operation.Transfer.self)
        case .transfer_to_vesting: op = try container.decode(Operation.TransferToVesting.self)
        case .withdraw_vesting: op = try container.decode(Operation.WithdrawVesting.self)
        case .account_create: op = try container.decode(Operation.AccountCreate.self)
        case .account_update: op = try container.decode(Operation.AccountUpdate.self)
        case .validator_update: op = try container.decode(Operation.ValidatorUpdate.self)
        case .account_validator_vote: op = try container.decode(Operation.AccountValidatorVote.self)
        case .account_validator_proxy: op = try container.decode(Operation.AccountValidatorProxy.self)
        case .custom: op = try container.decode(Operation.Custom.self)
        case .request_account_recovery: op = try container.decode(Operation.RequestAccountRecovery.self)
        case .recover_account: op = try container.decode(Operation.RecoverAccount.self)
        case .change_recovery_account: op = try container.decode(Operation.ChangeRecoveryAccount.self)
        case .escrow_transfer: op = try container.decode(Operation.EscrowTransfer.self)
        case .escrow_dispute: op = try container.decode(Operation.EscrowDispute.self)
        case .escrow_release: op = try container.decode(Operation.EscrowRelease.self)
        case .escrow_approve: op = try container.decode(Operation.EscrowApprove.self)
        case .delegate_vesting_shares: op = try container.decode(Operation.DelegateVestingShares.self)
        case .author_reward: op = try container.decode(Operation.AuthorReward.self)
        case .curation_reward: op = try container.decode(Operation.CurationReward.self)
        case .fill_vesting_withdraw: op = try container.decode(Operation.FillVestingWithdraw.self)
        case .shutdown_validator: op = try container.decode(Operation.ShutdownValidator.self)
        case .hardfork: op = try container.decode(Operation.Hardfork.self)
        case .return_vesting_delegation: op = try container.decode(Operation.ReturnVestingDelegation.self)
        case .validator_reward: op = try container.decode(Operation.ValidatorReward.self)
        case .create_invite: op = Operation.Unknown()
        case .claim_invite_balance: op = Operation.Unknown()
        case .invite_registration: op = try container.decode(Operation.InviteRegistration.self)
        case .versioned_chain_properties_update: op = Operation.Unknown()
        case .award: op = try container.decode(Operation.Award.self)
        case .receive_award: op = try container.decode(Operation.ReceiveAward.self)
        case .benefactor_award: op = try container.decode(Operation.BenefactorAward.self)
        case .set_paid_subscription: op = Operation.Unknown()
        case .paid_subscribe: op = Operation.Unknown()
        case .paid_subscription_action: op = Operation.Unknown()
        case .cancel_paid_subscription: op = Operation.Unknown()
        case .set_account_price: op = Operation.Unknown()
        case .set_subaccount_price: op = Operation.Unknown()
        case .buy_account: op = Operation.Unknown()
        case .account_sale: op = Operation.Unknown()
        case .delete_content: op = try container.decode(Operation.DeleteContent.self)
        case .set_withdraw_vesting_route: op = try container.decode(Operation.SetWithdrawVestingRoute.self)
        case .account_metadata: op = Operation.Unknown()
        case .proposal_create: op = Operation.Unknown()
        case .proposal_update: op = Operation.Unknown()
        case .proposal_delete: op = Operation.Unknown()
        case .chain_properties_update: op = Operation.Unknown()
        case .content_reward: op = try container.decode(Operation.CommentReward.self)
        case .content_payout_update: op = Operation.Unknown()
        case .content_benefactor_reward: op = Operation.Unknown()
        case .committee_worker_create_request: op = Operation.Unknown()
        case .committee_worker_cancel_request: op = Operation.Unknown()
        case .committee_vote_request: op = Operation.Unknown()
        case .committee_cancel_request: op = Operation.Unknown()
        case .committee_approve_request: op = Operation.Unknown()
        case .committee_payout_request: op = Operation.Unknown()
        case .committee_pay_request: op = Operation.Unknown()
        case .use_invite_balance: op = Operation.Unknown()
        case .expire_escrow_ratification: op = Operation.Unknown()
        case .fixed_award: op = try container.decode(Operation.FixedAward.self)
        case .target_account_sale: op = try container.decode(Operation.TargetAccountSale.self)
        case .bid: op = try container.decode(Operation.Bid.self)
        case .outbid: op = try container.decode(Operation.Outbid.self)
        case .set_reward_sharing: op = try container.decode(Operation.SetRewardSharing.self)
        case .stakeholder_reward: op = try container.decode(Operation.StakeholderReward.self)
        case .pm_oracle_register: op = try container.decode(Operation.PmOracleRegister.self)
        case .pm_oracle_update: op = try container.decode(Operation.PmOracleUpdate.self)
        case .pm_create_market: op = try container.decode(Operation.PmCreateMarket.self)
        case .pm_oracle_accept_market: op = try container.decode(Operation.PmOracleAcceptMarket.self)
        case .pm_place_bet: op = try container.decode(Operation.PmPlaceBet.self)
        case .pm_commit_bet: op = try container.decode(Operation.PmCommitBet.self)
        case .pm_reveal_bet: op = try container.decode(Operation.PmRevealBet.self)
        case .pm_cancel_bet: op = try container.decode(Operation.PmCancelBet.self)
        case .pm_add_liquidity: op = try container.decode(Operation.PmAddLiquidity.self)
        case .pm_withdraw_liquidity: op = try container.decode(Operation.PmWithdrawLiquidity.self)
        case .pm_resolve_market: op = try container.decode(Operation.PmResolveMarket.self)
        case .pm_no_contest: op = try container.decode(Operation.PmNoContest.self)
        case .pm_dispute_create: op = try container.decode(Operation.PmDisputeCreate.self)
        case .pm_dispute_vote: op = try container.decode(Operation.PmDisputeVote.self)
        case .pm_dispute_resolve: op = try container.decode(Operation.PmDisputeResolve.self)
        case .pm_transfer_position: op = try container.decode(Operation.PmTransferPosition.self)
        case .pm_lazy_deposit: op = try container.decode(Operation.PmLazyDeposit.self)
        case .pm_lazy_withdraw: op = try container.decode(Operation.PmLazyWithdraw.self)
        case .pm_batch_settle: op = try container.decode(Operation.PmBatchSettle.self)
        case .pm_commit_forfeit: op = try container.decode(Operation.PmCommitForfeit.self)
        case .pm_auto_payout: op = try container.decode(Operation.PmAutoPayout.self)
        case .pm_dispute_finalize: op = try container.decode(Operation.PmDisputeFinalize.self)
        case .pm_dispute_auto_close: op = try container.decode(Operation.PmDisputeAutoClose.self)
        case .pm_oracle_missed_penalty: op = try container.decode(Operation.PmOracleMissedPenalty.self)
        case .pm_lazy_recall: op = try container.decode(Operation.PmLazyRecall.self)
        case .pm_leverage_open: op = try container.decode(Operation.PmLeverageOpen.self)
        case .pm_leverage_close: op = try container.decode(Operation.PmLeverageClose.self)
        case .pm_leverage_convert: op = try container.decode(Operation.PmLeverageConvert.self)
        case .pm_leverage_liquidate: op = try container.decode(Operation.PmLeverageLiquidate.self)
        case .pm_leverage_resolve: op = try container.decode(Operation.PmLeverageResolve.self)
        case .pm_market_accepted: op = try container.decode(Operation.PmMarketAccepted.self)
        case .pm_payout: op = try container.decode(Operation.PmPayout.self)
        case .pm_dispute_oracle_respond: op = try container.decode(Operation.PmDisputeOracleRespond.self)
        case .pm_unban: op = try container.decode(Operation.PmUnban.self)
        case .pm_ban_expired: op = try container.decode(Operation.PmBanExpired.self)
        case .pm_market_expired: op = try container.decode(Operation.PmMarketExpired.self)
        case .pm_dispute_opened: op = try container.decode(Operation.PmDisputeOpened.self)
        case .pm_early_exit_claim_paid: op = try container.decode(Operation.PmEarlyExitClaimPaid.self)
        case .pm_lp_payout: op = try container.decode(Operation.PmLpPayout.self)
        case .set_agent_permission: op = try container.decode(Operation.SetAgentPermission.self)
        case .unknown: op = Operation.Unknown()
        }
        self.operation = op
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self.operation {
        case let op as Operation.Vote:
            try container.encode(OperationId.vote)
            try container.encode(op)
        case let op as Operation.Content:
            try container.encode(OperationId.content)
            try container.encode(op)
        case let op as Operation.Transfer:
            try container.encode(OperationId.transfer)
            try container.encode(op)
        case let op as Operation.TransferToVesting:
            try container.encode(OperationId.transfer_to_vesting)
            try container.encode(op)
        case let op as Operation.WithdrawVesting:
            try container.encode(OperationId.withdraw_vesting)
            try container.encode(op)
        case let op as Operation.AccountCreate:
            try container.encode(OperationId.account_create)
            try container.encode(op)
        case let op as Operation.AccountUpdate:
            try container.encode(OperationId.account_update)
            try container.encode(op)
        case let op as Operation.ValidatorUpdate:
            try container.encode(OperationId.validator_update)
            try container.encode(op)
        case let op as Operation.AccountValidatorVote:
            try container.encode(OperationId.account_validator_vote)
            try container.encode(op)
        case let op as Operation.AccountValidatorProxy:
            try container.encode(OperationId.account_validator_proxy)
            try container.encode(op)
        case let op as Operation.Custom:
            try container.encode(OperationId.custom)
            try container.encode(op)
        case let op as Operation.DeleteContent:
            try container.encode(OperationId.delete_content)
            try container.encode(op)
        case let op as Operation.SetWithdrawVestingRoute:
            try container.encode(OperationId.set_withdraw_vesting_route)
            try container.encode(op)
        case let op as Operation.RequestAccountRecovery:
            try container.encode(OperationId.request_account_recovery)
            try container.encode(op)
        case let op as Operation.RecoverAccount:
            try container.encode(OperationId.recover_account)
            try container.encode(op)
        case let op as Operation.ChangeRecoveryAccount:
            try container.encode(OperationId.change_recovery_account)
            try container.encode(op)
        case let op as Operation.EscrowTransfer:
            try container.encode(OperationId.escrow_transfer)
            try container.encode(op)
        case let op as Operation.EscrowDispute:
            try container.encode(OperationId.escrow_dispute)
            try container.encode(op)
        case let op as Operation.EscrowRelease:
            try container.encode(OperationId.escrow_release)
            try container.encode(op)
        case let op as Operation.EscrowApprove:
            try container.encode(OperationId.escrow_approve)
            try container.encode(op)
        case let op as Operation.DelegateVestingShares:
            try container.encode(OperationId.delegate_vesting_shares)
            try container.encode(op)
        case let op as Operation.Award:
            try container.encode(OperationId.award)
            try container.encode(op)
        case let op as Operation.ReceiveAward:
            try container.encode(OperationId.receive_award)
            try container.encode(op)
        case let op as Operation.BenefactorAward:
            try container.encode(OperationId.benefactor_award)
            try container.encode(op)
        case let op as Operation.InviteRegistration:
            try container.encode(OperationId.invite_registration)
            try container.encode(op)
        case let op as Operation.FixedAward:
            try container.encode(OperationId.fixed_award)
            try container.encode(op)
        case let op as Operation.TargetAccountSale:
            try container.encode(OperationId.target_account_sale)
            try container.encode(op)
        case let op as Operation.SetRewardSharing:
            try container.encode(OperationId.set_reward_sharing)
            try container.encode(op)
        case let op as Operation.PmOracleRegister:
            try container.encode(OperationId.pm_oracle_register)
            try container.encode(op)
        case let op as Operation.PmOracleUpdate:
            try container.encode(OperationId.pm_oracle_update)
            try container.encode(op)
        case let op as Operation.PmCreateMarket:
            try container.encode(OperationId.pm_create_market)
            try container.encode(op)
        case let op as Operation.PmOracleAcceptMarket:
            try container.encode(OperationId.pm_oracle_accept_market)
            try container.encode(op)
        case let op as Operation.PmPlaceBet:
            try container.encode(OperationId.pm_place_bet)
            try container.encode(op)
        case let op as Operation.PmCommitBet:
            try container.encode(OperationId.pm_commit_bet)
            try container.encode(op)
        case let op as Operation.PmRevealBet:
            try container.encode(OperationId.pm_reveal_bet)
            try container.encode(op)
        case let op as Operation.PmCancelBet:
            try container.encode(OperationId.pm_cancel_bet)
            try container.encode(op)
        case let op as Operation.PmAddLiquidity:
            try container.encode(OperationId.pm_add_liquidity)
            try container.encode(op)
        case let op as Operation.PmWithdrawLiquidity:
            try container.encode(OperationId.pm_withdraw_liquidity)
            try container.encode(op)
        case let op as Operation.PmResolveMarket:
            try container.encode(OperationId.pm_resolve_market)
            try container.encode(op)
        case let op as Operation.PmNoContest:
            try container.encode(OperationId.pm_no_contest)
            try container.encode(op)
        case let op as Operation.PmDisputeCreate:
            try container.encode(OperationId.pm_dispute_create)
            try container.encode(op)
        case let op as Operation.PmDisputeVote:
            try container.encode(OperationId.pm_dispute_vote)
            try container.encode(op)
        case let op as Operation.PmDisputeResolve:
            try container.encode(OperationId.pm_dispute_resolve)
            try container.encode(op)
        case let op as Operation.PmTransferPosition:
            try container.encode(OperationId.pm_transfer_position)
            try container.encode(op)
        case let op as Operation.PmLazyDeposit:
            try container.encode(OperationId.pm_lazy_deposit)
            try container.encode(op)
        case let op as Operation.PmLazyWithdraw:
            try container.encode(OperationId.pm_lazy_withdraw)
            try container.encode(op)
        case let op as Operation.PmLeverageOpen:
            try container.encode(OperationId.pm_leverage_open)
            try container.encode(op)
        case let op as Operation.PmLeverageClose:
            try container.encode(OperationId.pm_leverage_close)
            try container.encode(op)
        case let op as Operation.PmLeverageConvert:
            try container.encode(OperationId.pm_leverage_convert)
            try container.encode(op)
        case let op as Operation.PmDisputeOracleRespond:
            try container.encode(OperationId.pm_dispute_oracle_respond)
            try container.encode(op)
        case let op as Operation.PmUnban:
            try container.encode(OperationId.pm_unban)
            try container.encode(op)
        case let op as Operation.SetAgentPermission:
            try container.encode(OperationId.set_agent_permission)
            try container.encode(op)
        default:
            throw EncodingError.invalidValue(self.operation, EncodingError.Context(
                codingPath: container.codingPath, debugDescription: "Encountered unknown operation type"
            ))
        }
    }
}

fileprivate struct BeneficiaryWrapper: VIZEncodable, Equatable, Decodable {
    var beneficiaries: [Operation.CommentOptions.BeneficiaryRoute]
}

extension Operation.CommentOptions.Extension {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(Int.self)
        switch type {
        case 0:
            let wrapper = try BeneficiaryWrapper(from: container.superDecoder())
            self = .commentPayoutBeneficiaries(wrapper.beneficiaries)
        default:
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .commentPayoutBeneficiaries(routes):
            try container.encode(0 as Int)
            try container.encode(BeneficiaryWrapper(beneficiaries: routes))
        case .unknown:
            throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Encountered unknown comment extension"))
        }
    }
}

// MARK: - Deprecated aliases (witness → validator migration, 2026-05-19)

extension Operation {
    @available(*, deprecated, renamed: "ValidatorUpdate")
    public typealias WitnessUpdate = ValidatorUpdate

    @available(*, deprecated, renamed: "AccountValidatorVote")
    public typealias AccountWitnessVote = AccountValidatorVote

    @available(*, deprecated, renamed: "AccountValidatorProxy")
    public typealias AccountWitnessProxy = AccountValidatorProxy

    @available(*, deprecated, renamed: "ShutdownValidator")
    public typealias ShutdownWitness = ShutdownValidator

    @available(*, deprecated, renamed: "ValidatorReward")
    public typealias WitnessReward = ValidatorReward
}
