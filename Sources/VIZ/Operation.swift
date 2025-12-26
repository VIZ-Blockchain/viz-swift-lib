/// VIZ operation types.
/// - Author: Johan Nordberg <johan@steemit.com>

import Foundation

/// A type that represents a operation on the VIZ blockchain.
public protocol OperationType: VIZCodable {
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

    /// Convert operation.
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

    /// Registers or updates witnesses.
    public struct WitnessUpdate: OperationType, Equatable {
        /// Witness chain properties.
        public struct Properties: VIZCodable, Equatable {
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

    /// Votes for a witness.
    public struct AccountWitnessVote: OperationType, Equatable {
        public var account: String
        public var witness: String
        public var approve: Bool

        public init(account: String, witness: String, approve: Bool) {
            self.account = account
            self.witness = witness
            self.approve = approve
        }
    }

    /// Sets a witness voting proxy.
    public struct AccountWitnessProxy: OperationType, Equatable {
        public var account: String
        public var proxy: String

        public init(account: String, proxy: String) {
            self.account = account
            self.proxy = proxy
        }
    }

    /// Submits a proof of work, legacy.
    public struct Pow: OperationType, Equatable {}

    /// Custom operation.
    public struct Custom: OperationType, Equatable {
        public var requiredRegularAuths: [String]
        public var requiredActiveAuths: [String]
        public var id: UInt16
        public var data: Data

        public init(
            requiredRegularAuths: [String],
            requiredActiveAuths: [String],
            id: UInt16,
            data: Data
        ) {
            self.requiredRegularAuths = requiredRegularAuths
            self.requiredActiveAuths = requiredActiveAuths
            self.id = id
            self.data = data
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
        public struct BeneficiaryRoute: VIZCodable, Equatable {
            public var account: String
            public var weight: UInt16
        }

        /// Comment option extensions.
        public enum Extension: VIZCodable, Equatable {
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

    /// Submits equihash proof of work, legacy.
    public struct Pow2: OperationType, Equatable {}

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

    public struct ShutdownWitness: OperationType, Equatable {
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

    public struct WitnessReward: OperationType, Equatable {
        public var isVirtual: Bool { return true }
        public let witness: String
        public let shares: Asset
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
    case witness_update = 6
    case account_witness_vote = 7
    case account_witness_proxy = 8
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
    case shutdown_witness = 30
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
    case witness_reward = 42
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
        case "witness_update": self = .witness_update
        case "account_witness_vote": self = .account_witness_vote
        case "account_witness_proxy": self = .account_witness_proxy
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
        case "shutdown_witness": self = .shutdown_witness
        case "hardfork": self = .hardfork
        case "return_vesting_delegation": self = .return_vesting_delegation
        case "witness_reward": self = .witness_reward
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
internal struct AnyOperation: VIZEncodable, Decodable {
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
        case .witness_update: op = try container.decode(Operation.WitnessUpdate.self)
        case .account_witness_vote: op = try container.decode(Operation.AccountWitnessVote.self)
        case .account_witness_proxy: op = try container.decode(Operation.AccountWitnessProxy.self)
        case .custom: op = try container.decode(Operation.CustomJson.self)
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
        case .shutdown_witness: op = try container.decode(Operation.ShutdownWitness.self)
        case .hardfork: op = try container.decode(Operation.Hardfork.self)
        case .return_vesting_delegation: op = try container.decode(Operation.ReturnVestingDelegation.self)
        case .witness_reward: op = try container.decode(Operation.WitnessReward.self)
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
        case let op as Operation.WitnessUpdate:
            try container.encode(OperationId.witness_update)
            try container.encode(op)
        case let op as Operation.AccountWitnessVote:
            try container.encode(OperationId.account_witness_vote)
            try container.encode(op)
        case let op as Operation.AccountWitnessProxy:
            try container.encode(OperationId.account_witness_proxy)
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
