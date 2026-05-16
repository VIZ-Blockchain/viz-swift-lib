import OrderedDictionary
@testable import VIZ
import XCTest

class VIZEncoderTest: XCTestCase {
    func testFixedWidthInteger() {
        AssertEncodes(0 as Int8, Data("00"))
        AssertEncodes(-128 as Int8, Data("80"))
        AssertEncodes(127 as Int8, Data("7f"))
        AssertEncodes(-32768 as Int16, Data("0080"))
        AssertEncodes(255 as Int16, Data("ff00"))
        AssertEncodes(-4162 as Int16, Data("beef"))
        AssertEncodes(-272_707_846 as Int32, Data("facebeef"))
        AssertEncodes(9_007_199_254_740_991 as Int64, Data("ffffffffffff1f00"))
        AssertEncodes(-9_007_199_254_740_991 as Int64, Data("010000000000e0ff"))
        AssertEncodes(255 as UInt8, Data("ff"))
        AssertEncodes(61374 as UInt16, Data("beef"))
        AssertEncodes(4_022_259_450 as UInt32, Data("facebeef"))
        AssertEncodes(9_007_199_254_740_991 as UInt64, Data("ffffffffffff1f00"))
    }

    func testString() {
        AssertEncodes("", Data("00"))
        AssertEncodes("Hellö fröm Swäden!", Data("1548656c6cc3b6206672c3b66d205377c3a464656e21"))
        AssertEncodes("大きなおっぱい", Data("15e5a4a7e3818de381aae3818ae381a3e381b1e38184"))
    }

    func testArray() {
        AssertEncodes(["foo", "bar"], Data("0203666f6f03626172"))
        AssertEncodes([100 as UInt16, 200 as UInt16], Data("026400c800"))
    }

    func testSortedDict() {
        let map1: OrderedDictionary = [(190 as UInt8, 239 as UInt8), (250 as UInt8, 206 as UInt8)]
        AssertEncodes(map1, Data("02beefface"))
        let map2: OrderedDictionary = [("2k", Date(timeIntervalSince1970: 946_684_800))]
        AssertEncodes(map2, Data("0102326b80436d38"))
    }

    func testBool() {
        AssertEncodes(true, Data("01"))
        AssertEncodes(false, Data("00"))
    }

    func testDate() {
        // UInt32 little-endian seconds since 1970
        AssertEncodes(Date(timeIntervalSince1970: 0), Data("00000000"))
        // 1700000000 = 0x6553f100 → little-endian: 00 f1 53 65
        AssertEncodes(Date(timeIntervalSince1970: 1_700_000_000), Data("00f15365"))
    }

    func testOptional() {
        AssertEncodes(Optional<UInt16>.some(0xbeef), Data("01efbe"))
        AssertEncodes(Optional<UInt16>.none, Data("00"))
    }

    func testRawData() {
        // Data appends raw bytes with NO length prefix (pinned behavior).
        AssertEncodes(Data([0x01, 0x02, 0x03]), Data("010203"))
    }

    func testVarintBoundaries() {
        // appendVarint is internal — use a String which calls it for its length prefix.
        // 0-byte string → length varint of 0 → 0x00
        AssertEncodes("", Data("00"))
        // 127-byte string → length varint of 127 → 0x7f
        let s127 = String(repeating: "a", count: 127)
        AssertEncodes(s127, Data("7f" + String(repeating: "61", count: 127)))
        // 128-byte string → length varint of 128 → 0x80 0x01
        let s128 = String(repeating: "a", count: 128)
        AssertEncodes(s128, Data("8001" + String(repeating: "61", count: 128)))
    }

    func testLargeArrayVarintLength() {
        // 200 UInt16 elements → length prefix is c8 01 (200), followed by 400 bytes of element data.
        let arr = Array(repeating: UInt16(0), count: 200)
        let expectedHex = "c801" + String(repeating: "0000", count: 200)
        AssertEncodes(arr, Data(expectedHex))
    }
}
