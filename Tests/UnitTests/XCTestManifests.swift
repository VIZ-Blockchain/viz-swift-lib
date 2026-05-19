import XCTest

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

extension OperationTest {
    static let __allTests = [
        ("testDecodable", testDecodable),
        ("testEncodable", testEncodable),
        ("testEncodeAsymmetry_definedButNotEncodable", testEncodeAsymmetry_definedButNotEncodable),
        ("testRoundTrip_accountCreate", testRoundTrip_accountCreate),
        ("testRoundTrip_accountUpdate", testRoundTrip_accountUpdate),
        ("testRoundTrip_accountWitnessProxy", testRoundTrip_accountWitnessProxy),
        ("testRoundTrip_accountWitnessVote", testRoundTrip_accountWitnessVote),
        ("testRoundTrip_award", testRoundTrip_award),
        ("testRoundTrip_benefactorAward", testRoundTrip_benefactorAward),
        ("testRoundTrip_changeRecoveryAccount", testRoundTrip_changeRecoveryAccount),
        ("testRoundTrip_content", testRoundTrip_content),
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
        ("testVirtualDecode_shutdownWitness", testVirtualDecode_shutdownWitness),
        ("testVirtualDecode_witnessReward", testVirtualDecode_witnessReward),
    ]
}

extension PrivateKeyTest {
    static let __allTests = [
        ("testCreatePublic", testCreatePublic),
        ("testDecodeWif", testDecodeWif),
        ("testEquatable", testEquatable),
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
        ("testDecodable", testDecodable),
        ("testSigning", testSigning),
    ]
}

#if !os(macOS)
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase(AssetTest.__allTests),
            testCase(Base58Test.__allTests),
            testCase(BlockTest.__allTests),
            testCase(ClientTest.__allTests),
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
