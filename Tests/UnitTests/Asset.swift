
import Foundation
@testable import VIZ
import XCTest

class AssetTest: XCTestCase {
    func testEncodable() {
        AssertEncodes(Asset(10, .viz), Data("10270000000000000356495a00000000"))
        AssertEncodes(Asset(123_456.789, .vests), Data("081a99be1c0000000656455354530000"))
        AssertEncodes(Asset(10, .viz), "10.000 VIZ")
        AssertEncodes(Asset(123_456.789, .vests), "123456.789000 VESTS")
    }

    func testProperties() {
        let mockAsset = Asset(0.001, .viz)
        XCTAssertEqual(mockAsset.description, "0.001 VIZ")
        XCTAssertEqual(mockAsset.amount, 1)
        XCTAssertEqual(mockAsset.symbol, Asset.Symbol.viz)
        XCTAssertEqual(mockAsset.resolvedAmount, 0.001)
    }

    func testEquateable() {
        let mockAsset1 = Asset(0.1, .viz)
        let mockAsset2 = Asset(0.1, .vests)
        let mockAsset3 = Asset(0.1, .viz)
        XCTAssertFalse(mockAsset1 == mockAsset2)
        XCTAssertTrue(mockAsset1 == mockAsset3)
    }

    func testDecodable() throws {
        AssertDecodes(string: "10.000 VIZ", Asset(10, .viz))
        AssertDecodes(string: "0.001 VIZ", Asset(0.001, .viz))
        AssertDecodes(string: "123456789.999999 VESTS", Asset(123_456_789.999999, .vests))
    }

    // MARK: - String parsing edge cases

    func testMalformedStringsReturnNil() {
        XCTAssertNil(Asset(""))
        XCTAssertNil(Asset("VIZ"))
        XCTAssertNil(Asset("10.000"))
        XCTAssertNil(Asset("10.000VIZ"))
        XCTAssertNil(Asset("abc VIZ"))
        XCTAssertNil(Asset("10..0 VIZ"))
    }

    func testCustomSymbolPrecisionInference() {
        let a = Asset("10.123456 FOO")
        XCTAssertEqual(a?.symbol, .custom(name: "FOO", precision: 6))

        let b = Asset("10 FOO")
        XCTAssertEqual(b?.symbol, .custom(name: "FOO", precision: 0))

        let c = Asset("10. FOO")
        XCTAssertEqual(c?.symbol, .custom(name: "FOO", precision: 0))
    }

    func testNegativeAndZero() {
        let neg = Asset(-1.5, .viz)
        XCTAssertEqual(neg.description, "-1.500 VIZ")
        XCTAssertEqual(neg.resolvedAmount, -1.5)

        let zero = Asset(0, .viz)
        XCTAssertEqual(zero.description, "0.000 VIZ")
        XCTAssertEqual(zero.resolvedAmount, 0.0)
    }

    func testDescriptionExactPrecision() {
        XCTAssertEqual(Asset(1, .viz).description, "1.000 VIZ")
        XCTAssertEqual(Asset(1, .vests).description, "1.000000 VESTS")
        XCTAssertEqual(Asset(1, .custom(name: "FOO", precision: 2)).description, "1.00 FOO")
    }

    // MARK: - Binary encoding for non-VIZ symbols

    func testEncodeVestsBinary() {
        AssertEncodes(Asset(1, .vests), Data("40420f00000000000656455354530000"))
    }

    func testEncodeCustomShortSymbolBinary() {
        AssertEncodes(Asset(1, .custom(name: "FOO", precision: 2)), Data("640000000000000002464f4f00000000"))
    }

    // MARK: - Decode failure

    func testDecodeFailsOnMalformedString() {
        do {
            _ = try TestDecode(Asset.self, string: "not an asset")
            XCTFail("Expected DecodingError")
        } catch is DecodingError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
