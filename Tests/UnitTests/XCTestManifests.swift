import XCTest

extension APITest {
    static let __allTests = [
        ("testCurrentEnergy_atExplicitDate", testCurrentEnergy_atExplicitDate),
        ("testCurrentEnergy_fullRegenerationCapped", testCurrentEnergy_fullRegenerationCapped),
        ("testCurrentEnergy_initialAboveCap", testCurrentEnergy_initialAboveCap),
        ("testCurrentEnergy_negativeEnergy", testCurrentEnergy_negativeEnergy),
        ("testCurrentEnergy_noRegeneration", testCurrentEnergy_noRegeneration),
        ("testCurrentEnergy_partialRegeneration", testCurrentEnergy_partialRegeneration),
        ("testDynamicGlobalProperties_decodesLegacyKeys", testDynamicGlobalProperties_decodesLegacyKeys),
        ("testDynamicGlobalProperties_decodesNewKeys", testDynamicGlobalProperties_decodesNewKeys),
        ("testEffectiveVestingShares_allZero", testEffectiveVestingShares_allZero),
        ("testEffectiveVestingShares_delegatedMoreThanReceived", testEffectiveVestingShares_delegatedMoreThanReceived),
        ("testEffectiveVestingShares_largeValues", testEffectiveVestingShares_largeValues),
        ("testEffectiveVestingShares_normalCase", testEffectiveVestingShares_normalCase),
        ("testExtendedAccount_decodesLegacyWitnessKeys", testExtendedAccount_decodesLegacyWitnessKeys),
        ("testExtendedAccount_decodesNewValidatorKeys", testExtendedAccount_decodesNewValidatorKeys),
        ("testShare_decodesStringValue", testShare_decodesStringValue),
        ("testShare_throwsOnUnparseableString", testShare_throwsOnUnparseableString),
    ]
}

extension AssetTest {
    static let __allTests = [
        ("testCustomSymbolPrecisionInference", testCustomSymbolPrecisionInference),
        ("testDecodable", testDecodable),
        ("testDecodeFailsOnMalformedString", testDecodeFailsOnMalformedString),
        ("testDescriptionExactPrecision", testDescriptionExactPrecision),
        ("testEncodable", testEncodable),
        ("testEncodeCustomShortSymbolBinary", testEncodeCustomShortSymbolBinary),
        ("testEncodeVestsBinary", testEncodeVestsBinary),
        ("testEquateable", testEquateable),
        ("testMalformedStringsReturnNil", testMalformedStringsReturnNil),
        ("testNegativeAndZero", testNegativeAndZero),
        ("testProperties", testProperties),
    ]
}

extension Base58Test {
    static let __allTests = [
        ("testDecode", testDecode),
        ("testEncode", testEncode),
    ]
}

extension BlockTest {
    static let __allTests = [
        ("testCodable", testCodable),
        ("testDecode_signedBlock_acceptsNewValidatorKeys", testDecode_signedBlock_acceptsNewValidatorKeys),
    ]
}

extension ChainIdTest {
    static let __allTests = [
        ("testEncodeCustomChainId", testEncodeCustomChainId),
        ("testMainnetId", testMainnetId),
        ("testTestnetId", testTestnetId),
    ]
}

extension ClientTest {
    static let __allTests = [
        ("testBadRpcResponse", testBadRpcResponse),
        ("testBadServerResponse", testBadServerResponse),
        ("testRequest", testRequest),
        ("testRequestWithParams", testRequestWithParams),
        ("testRpcError", testRpcError),
    ]
}

@available(*, deprecated, message: "Manifest entry for the deprecated witness→validator compile-smoke test class.")
extension DeprecatedAliasesTest {
    static let __allTests = [
        ("testApiDeprecatedProperties", testApiDeprecatedProperties),
        ("testBlockHeaderDeprecatedProperties", testBlockHeaderDeprecatedProperties),
        ("testOperationDeprecatedInits", testOperationDeprecatedInits),
        ("testOperationTypealiases", testOperationTypealiases),
    ]
}

extension OperationTest {
    static let __allTests = [
        ("testDecode_accountValidatorVote_legacyWitnessKey", testDecode_accountValidatorVote_legacyWitnessKey),
        ("testDecode_validatorReward_legacyWitnessKey", testDecode_validatorReward_legacyWitnessKey),
        ("testDecodable", testDecodable),
        ("testEncodable", testEncodable),
        ("testEncodeAsymmetry_definedButNotEncodable", testEncodeAsymmetry_definedButNotEncodable),
        ("testOperationId_acceptsLegacyAndNewNames", testOperationId_acceptsLegacyAndNewNames),
        ("testRoundTrip_accountCreate", testRoundTrip_accountCreate),
        ("testRoundTrip_accountUpdate", testRoundTrip_accountUpdate),
        ("testRoundTrip_accountValidatorProxy", testRoundTrip_accountValidatorProxy),
        ("testRoundTrip_accountValidatorVote", testRoundTrip_accountValidatorVote),
        ("testRoundTrip_award", testRoundTrip_award),
        ("testRoundTrip_benefactorAward", testRoundTrip_benefactorAward),
        ("testRoundTrip_changeRecoveryAccount", testRoundTrip_changeRecoveryAccount),
        ("testRoundTrip_content", testRoundTrip_content),
        ("testRoundTrip_custom", testRoundTrip_custom),
        ("testRoundTrip_delegateVestingShares", testRoundTrip_delegateVestingShares),
        ("testRoundTrip_escrowApprove", testRoundTrip_escrowApprove),
        ("testRoundTrip_escrowDispute", testRoundTrip_escrowDispute),
        ("testRoundTrip_escrowRelease", testRoundTrip_escrowRelease),
        ("testRoundTrip_escrowTransfer", testRoundTrip_escrowTransfer),
        ("testRoundTrip_inviteRegistration", testRoundTrip_inviteRegistration),
        ("testRoundTrip_receiveAward", testRoundTrip_receiveAward),
        ("testRoundTrip_recoverAccount", testRoundTrip_recoverAccount),
        ("testRoundTrip_requestAccountRecovery", testRoundTrip_requestAccountRecovery),
        ("testRoundTrip_setWithdrawVestingRoute", testRoundTrip_setWithdrawVestingRoute),
        ("testRoundTrip_transfer", testRoundTrip_transfer),
        ("testRoundTrip_transferToVesting", testRoundTrip_transferToVesting),
        ("testRoundTrip_validatorUpdate", testRoundTrip_validatorUpdate),
        ("testRoundTrip_vote", testRoundTrip_vote),
        ("testRoundTrip_withdrawVesting", testRoundTrip_withdrawVesting),
        ("testUnknownMappedOps_decodeAsUnknown", testUnknownMappedOps_decodeAsUnknown),
        ("testVirtual", testVirtual),
        ("testVirtualDecode_authorReward", testVirtualDecode_authorReward),
        ("testVirtualDecode_commentPayoutUpdate", testVirtualDecode_commentPayoutUpdate),
        ("testVirtualDecode_commentReward", testVirtualDecode_commentReward),
        ("testVirtualDecode_curationReward", testVirtualDecode_curationReward),
        ("testVirtualDecode_fillConvertRequest", testVirtualDecode_fillConvertRequest),
        ("testVirtualDecode_fillOrder", testVirtualDecode_fillOrder),
        ("testVirtualDecode_fillTransferFromSavings", testVirtualDecode_fillTransferFromSavings),
        ("testVirtualDecode_fillVestingWithdraw", testVirtualDecode_fillVestingWithdraw),
        ("testVirtualDecode_hardfork", testVirtualDecode_hardfork),
        ("testVirtualDecode_interest", testVirtualDecode_interest),
        ("testVirtualDecode_liquidityReward", testVirtualDecode_liquidityReward),
        ("testVirtualDecode_returnVestingDelegation", testVirtualDecode_returnVestingDelegation),
        ("testVirtualDecode_shutdownValidator", testVirtualDecode_shutdownValidator),
        ("testVirtualDecode_validatorReward", testVirtualDecode_validatorReward),
    ]
}

extension PrivateKeyTest {
    static let __allTests = [
        ("testCreatePublic", testCreatePublic),
        ("testDecodeWif", testDecodeWif),
        ("testEquatable", testEquatable),
        ("testGeneratePrivateFromSeed", testGeneratePrivateFromSeed),
        ("testHandlesInvalid", testHandlesInvalid),
        ("testSign", testSign),
    ]
}

extension PublicKeyTest {
    static let __allTests = [
        ("testCustomKey", testCustomKey),
        ("testDecodable", testDecodable),
        ("testEncodable", testEncodable),
        ("testInvalidKeys", testInvalidKeys),
        ("testKey", testKey),
        ("testNullKey", testNullKey),
//        ("testTestnetKey", testTestnetKey),
    ]
}

extension Secp256k1Test {
    static let __allTests = [
        ("testPublicFromPrivate", testPublicFromPrivate),
        ("testSignAndRecover", testSignAndRecover),
        ("testVerifiesSecret", testVerifiesSecret),
    ]
}

extension VIZURLTest {
    static let __allTests = [
        ("testEncodeDecode", testEncodeDecode),
        ("testParams", testParams),
    ]
}

extension Sha2Test {
    static let __allTests = [
        ("testDigest", testDigest),
    ]
}

extension SignatureTest {
    static let __allTests = [
        ("testEncodable", testEncodable),
        ("testEncodeDecode", testEncodeDecode),
        ("testRecover", testRecover),
    ]
}

extension VIZEncoderTest {
    static let __allTests = [
        ("testArray", testArray),
        ("testBool", testBool),
        ("testDate", testDate),
        ("testFixedWidthInteger", testFixedWidthInteger),
        ("testLargeArrayVarintLength", testLargeArrayVarintLength),
        ("testOptional", testOptional),
        ("testRawData", testRawData),
        ("testSortedDict", testSortedDict),
        ("testString", testString),
        ("testVarintBoundaries", testVarintBoundaries),
    ]
}

extension TransactionTest {
    static let __allTests = [
        ("testAppend", testAppend),
        ("testDecodable", testDecodable),
        ("testInitWithOp", testInitWithOp),
        ("testSigning", testSigning),
    ]
}

#if !os(macOS)
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase(APITest.__allTests),
            testCase(AssetTest.__allTests),
            testCase(Base58Test.__allTests),
            testCase(BlockTest.__allTests),
            testCase(ChainIdTest.__allTests),
            testCase(ClientTest.__allTests),
            testCase(DeprecatedAliasesTest.__allTests),
            testCase(OperationTest.__allTests),
            testCase(PrivateKeyTest.__allTests),
            testCase(PublicKeyTest.__allTests),
            testCase(Secp256k1Test.__allTests),
            testCase(VIZURLTest.__allTests),
            testCase(Sha2Test.__allTests),
            testCase(SignatureTest.__allTests),
            testCase(VIZEncoderTest.__allTests),
            testCase(TransactionTest.__allTests),
        ]
    }
#endif
