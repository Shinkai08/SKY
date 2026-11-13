import XCTest
@testable import SKY

final class FormatTests: XCTestCase {
    func testGroupedNumbers() {
        XCTAssertEqual(Fmt.num(1234567.891, 2, lang: "en"), "1,234,567.89")
        XCTAssertEqual(Fmt.num(1234.5, 2, lang: "es"), "1.234,50")
        XCTAssertEqual(Fmt.num(-0.001, 2, lang: "en"), "0.00")
        XCTAssertEqual(Fmt.num(-12.5, 1, lang: "zh-CN"), "-12.5")
        XCTAssertEqual(Fmt.num(999, 0, lang: "en"), "999")
        XCTAssertEqual(Fmt.num(1000, 0, lang: "nl"), "1.000")
    }

    func testPct() {
        XCTAssertEqual(Fmt.pct(1.234), "+1.23%")
        XCTAssertEqual(Fmt.pct(-0.5), "−0.50%")
    }

    func testVipTiers() {
        XCTAssertEqual(VIP.tierFor(spot: true, assets: 150_000, volume: 0).level, 1)
        XCTAssertEqual(VIP.tierFor(spot: false, assets: 0, volume: 700e6).level, 5)
        XCTAssertEqual(VIP.pct(-0.00005), "−0.0050%")
    }

    func testIconsBuild() {
        for icon in Lucide.allCases { XCTAssertFalse(icon.path.isEmpty, icon.rawValue) }
    }
}
