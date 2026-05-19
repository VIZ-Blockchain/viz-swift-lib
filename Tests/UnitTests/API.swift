//
//  API.swift
//  VIZ
//
//  Created by Vladimir Babin on 12/27/25.
//

import Foundation
import XCTest
@testable import VIZ

final class APITest: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeAccount(
        energy: Int32,
        lastVoteTime: Date,
        vesting: Double = 0,
        received: Double = 0,
        delegated: Double = 0
    ) -> API.ExtendedAccount {
        API.ExtendedAccount(
            id: 1,
            name: "alice",
            masterAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ8LMF1uA5GAPfsAe1dieBRATQfhgi1ZqXYRFkaj1WaaWx9vVjau")!: 1]]),
            activeAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ56WPHZKvxoHpjQh69XakuoE5czuewrTDYeUBsQNKjnq3a6bbh6")!: 1]]),
            regularAuthority: Authority(weightThreshold: 1, accountAuths: [], keyAuths: [[PublicKey("VIZ5oPsxWgfCH2FWqcXBWeeMmZoyBY5baiuV1vQWMxVVpYxEsJ6Hx")!: 1]]),
            memoKey: PublicKey("VIZ7SSqMsrCqNZ3NdJLwWqC2u5PQ66JB2uCCs6ee5NFFqXxxB46AH")!,
            jsonMetadata: "{}",
            proxy: "",
            referrer: "",
            lastMasterUpdate: .distantPast,
            lastAccountUpdate: .distantPast,
            created: .distantPast,
            recoveryAccount: "",
            lastAccountRecovery: .distantPast,
            awardedRshares: 0,
            customSequence: 0,
            customSequenceBlockNum: 0,
            energy: energy,
            lastVoteTime: lastVoteTime,
            balance: Asset(0),
            receiverAwards: 0,
            benefactorAwards: 0,
            vestingShares: Asset(vesting),
            delegatedVestingShares: Asset(delegated),
            receivedVestingShares: Asset(received),
            vestingWithdrawRate: Asset(0),
            nextVestingWithdrawal: .distantFuture,
            withdrawn: API.Share(0),
            toWithdraw: API.Share(0),
            withdrawRoutes: 0,
            proxiedVsfVotes: [],
            witnessesVotedFor: 0,
            witnessesVoteWeight: API.Share(0),
            lastPost: .distantPast,
            lastRootPost: .distantPast,
            averageBandwidth: API.Share(0),
            lifetimeBandwidth: API.Share(0),
            lastBandwidthUpdate: .distantPast,
            witnessVotes: [],
            valid: true,
            accountSeller: "",
            accountOfferPrice: Asset(0),
            accountOnSale: false,
            subaccountSeller: "",
            subaccountOfferPrice: Asset(0),
            subaccountOnSale: false
        )
    }
    
    // MARK: - effectiveVestingShares
    
    func testEffectiveVestingShares_normalCase() {
        let account = makeAccount(
            energy: 0,
            lastVoteTime: .now,
            vesting: 100,
            received: 40,
            delegated: 10
        )
        
        XCTAssertEqual(account.effectiveVestingShares, 130)
    }
    
    func testEffectiveVestingShares_delegatedMoreThanReceived() {
        let account = makeAccount(
            energy: 0,
            lastVoteTime: .now,
            vesting: 100,
            received: 10,
            delegated: 50
        )
        
        XCTAssertEqual(account.effectiveVestingShares, 60)
    }
    
    func testEffectiveVestingShares_allZero() {
        let account = makeAccount(
            energy: 0,
            lastVoteTime: .now
        )
        
        XCTAssertEqual(account.effectiveVestingShares, 0)
    }
    
    func testEffectiveVestingShares_largeValues() {
        let account = makeAccount(
            energy: 0,
            lastVoteTime: .now,
            vesting: 1_000_000,
            received: 500_000,
            delegated: 250_000
        )
        
        XCTAssertEqual(account.effectiveVestingShares, 1_250_000)
    }
    
    // MARK: - currentEnergy
    
    func testCurrentEnergy_noRegeneration() {
        let now = Date()
        let account = makeAccount(
            energy: 5000,
            lastVoteTime: now
        )
        
        XCTAssertEqual(account.currentEnergy, 5000)
    }
    
    func testCurrentEnergy_partialRegeneration() {
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60
        let halfPeriod = fiveDays / 2
        
        let account = makeAccount(
            energy: 0,
            lastVoteTime: Date().addingTimeInterval(-halfPeriod)
        )
        
        XCTAssertEqual(account.currentEnergy, 5000, accuracy: 1)
    }
    
    func testCurrentEnergy_fullRegenerationCapped() {
        let fiveDays: TimeInterval = 5 * 24 * 60 * 60
        
        let account = makeAccount(
            energy: 2000,
            lastVoteTime: Date().addingTimeInterval(-fiveDays * 2)
        )
        
        XCTAssertEqual(account.currentEnergy, 10000)
    }
    
    func testCurrentEnergy_initialAboveCap() {
        let account = makeAccount(
            energy: 15000,
            lastVoteTime: Date()
        )
        
        XCTAssertEqual(account.currentEnergy, 10000)
    }
    
    func testCurrentEnergy_negativeEnergy() {
        let account = makeAccount(
            energy: -1000,
            lastVoteTime: Date()
        )

        XCTAssertGreaterThanOrEqual(account.currentEnergy, 0)
    }

    // MARK: - DynamicGlobalProperties decode

    func testDynamicGlobalProperties_decodesNewKeys() throws {
        let json = """
        {
          "head_block_number": 1,
          "head_block_id": "00000001aabbccddeeff",
          "time": "2026-05-19T12:00:00",
          "genesis_time": "2018-09-29T13:00:00",
          "current_validator": "alice",
          "committee_fund": "0.000 VIZ",
          "committee_requests": 0,
          "current_supply": "0.000 VIZ",
          "total_vesting_fund": "0.000 VIZ",
          "total_vesting_shares": "0.000000 VESTS",
          "total_reward_fund": "0.000 VIZ",
          "total_reward_shares": "0",
          "inflation_calc_block_num": 0,
          "inflation_validator_percent": 1500,
          "inflation_ratio": 0,
          "average_block_size": 0,
          "maximum_block_size": 0,
          "current_aslot": 0,
          "recent_slots_filled": "0",
          "participation_count": 0,
          "last_irreversible_block_num": 0,
          "max_virtual_bandwidth": "0",
          "current_reserve_ratio": 0,
          "vote_regeneration_per_day": 0
        }
        """
        let dgp = try TestDecode(API.DynamicGlobalProperties.self, json: json)
        XCTAssertEqual(dgp.currentValidator, "alice")
        XCTAssertEqual(dgp.inflationValidatorPercent, 1500)
    }

    func testDynamicGlobalProperties_decodesLegacyKeys() throws {
        let json = """
        {
          "head_block_number": 1,
          "head_block_id": "00000001aabbccddeeff",
          "time": "2026-05-19T12:00:00",
          "genesis_time": "2018-09-29T13:00:00",
          "current_witness": "alice",
          "committee_fund": "0.000 VIZ",
          "committee_requests": 0,
          "current_supply": "0.000 VIZ",
          "total_vesting_fund": "0.000 VIZ",
          "total_vesting_shares": "0.000000 VESTS",
          "total_reward_fund": "0.000 VIZ",
          "total_reward_shares": "0",
          "inflation_calc_block_num": 0,
          "inflation_witness_percent": 1500,
          "inflation_ratio": 0,
          "average_block_size": 0,
          "maximum_block_size": 0,
          "current_aslot": 0,
          "recent_slots_filled": "0",
          "participation_count": 0,
          "last_irreversible_block_num": 0,
          "max_virtual_bandwidth": "0",
          "current_reserve_ratio": 0,
          "vote_regeneration_per_day": 0
        }
        """
        let dgp = try TestDecode(API.DynamicGlobalProperties.self, json: json)
        XCTAssertEqual(dgp.currentValidator, "alice")
        XCTAssertEqual(dgp.inflationValidatorPercent, 1500)
    }
}
