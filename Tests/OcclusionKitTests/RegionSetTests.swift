import XCTest
@testable import OcclusionKit

final class RegionSetTests: XCTestCase {
    // MARK: - CGRect.subtracting Tests

    func testSubtractingNoIntersection() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 200, y: 200, width: 50, height: 50)

        let result = rect.subtracting(other)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, rect)
    }

    func testSubtractingFullyCovered() {
        let rect = CGRect(x: 50, y: 50, width: 50, height: 50)
        let other = CGRect(x: 0, y: 0, width: 200, height: 200)

        let result = rect.subtracting(other)

        XCTAssertEqual(result.count, 0)
    }

    func testSubtractingTopPortion() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 0, y: 0, width: 100, height: 50)

        let result = rect.subtracting(other)

        // Should have bottom piece remaining
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, CGRect(x: 0, y: 50, width: 100, height: 50))
    }

    func testSubtractingBottomPortion() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 0, y: 50, width: 100, height: 50)

        let result = rect.subtracting(other)

        // Should have top piece remaining
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testSubtractingLeftPortion() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 0, y: 0, width: 50, height: 100)

        let result = rect.subtracting(other)

        // Should have right piece remaining
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, CGRect(x: 50, y: 0, width: 50, height: 100))
    }

    func testSubtractingRightPortion() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 50, y: 0, width: 50, height: 100)

        let result = rect.subtracting(other)

        // Should have left piece remaining
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, CGRect(x: 0, y: 0, width: 50, height: 100))
    }

    func testSubtractingCenter() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 25, y: 25, width: 50, height: 50)

        let result = rect.subtracting(other)

        // Should have 4 pieces: top, bottom, left, right
        XCTAssertEqual(result.count, 4)

        let totalArea = result.reduce(0) { $0 + $1.width * $1.height }
        let expectedArea: CGFloat = 100 * 100 - 50 * 50 // Original minus subtracted
        XCTAssertEqual(totalArea, expectedArea)
    }

    func testSubtractingCorner() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let other = CGRect(x: 50, y: 50, width: 100, height: 100)

        let result = rect.subtracting(other)

        // Should have 2 pieces: top strip and left strip of middle row
        XCTAssertEqual(result.count, 2)

        let totalArea = result.reduce(0) { $0 + $1.width * $1.height }
        let expectedArea: CGFloat = 100 * 100 - 50 * 50 // Original minus intersection
        XCTAssertEqual(totalArea, expectedArea)
    }

    // MARK: - RegionSet Tests

    func testRegionSetEmpty() {
        let region = RegionSet()

        XCTAssertTrue(region.isEmpty)
        XCTAssertEqual(region.area, 0)
    }

    func testRegionSetSingleRect() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let region = RegionSet(rect: rect)

        XCTAssertFalse(region.isEmpty)
        XCTAssertEqual(region.area, 10000)
        XCTAssertEqual(region.rectangles.count, 1)
    }

    func testRegionSetSubtract() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        var region = RegionSet(rect: rect)

        region.subtract(CGRect(x: 0, y: 0, width: 100, height: 50))

        XCTAssertEqual(region.area, 5000)
    }

    func testRegionSetMultipleSubtracts() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        var region = RegionSet(rect: rect)

        // Subtract overlapping rectangles - should not double-count
        region.subtract(CGRect(x: 0, y: 0, width: 60, height: 60))
        region.subtract(CGRect(x: 40, y: 40, width: 60, height: 60))

        // The two 60x60 squares overlap in a 20x20 region
        // Total covered = 60*60 + 60*60 - 20*20 = 3600 + 3600 - 400 = 6800
        // Remaining = 10000 - 6800 = 3200
        XCTAssertEqual(region.area, 3200)
    }

    func testRegionSetSubtractCompletely() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        var region = RegionSet(rect: rect)

        region.subtract(CGRect(x: -10, y: -10, width: 200, height: 200))

        XCTAssertTrue(region.isEmpty)
        XCTAssertEqual(region.area, 0)
    }

    func testRegionSetImmutableSubtract() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let region = RegionSet(rect: rect)

        let newRegion = region.subtractingRect(CGRect(x: 0, y: 0, width: 50, height: 50))

        // Original unchanged
        XCTAssertEqual(region.area, 10000)
        // New region has subtracted area
        XCTAssertEqual(newRegion.area, 7500)
    }

    func testRegionSetInvalidRects() {
        let empty = RegionSet(rect: CGRect.zero)
        XCTAssertTrue(empty.isEmpty)

        let null = RegionSet(rect: CGRect.null)
        XCTAssertTrue(null.isEmpty)

        let infinite = RegionSet(rect: CGRect.infinite)
        XCTAssertTrue(infinite.isEmpty)
    }
}
