import XCTest
@testable import OcclusionKit

/// Mock window provider for testing
final class MockWindowProvider: WindowProvider, @unchecked Sendable {
    var mockWindows: [WindowInfo] = []

    func allWindows() throws -> [WindowInfo] {
        mockWindows
    }
}

final class OcclusionCalculatorTests: XCTestCase {
    var mockProvider: MockWindowProvider!
    var calculator: OcclusionCalculator!

    override func setUp() {
        super.setUp()
        mockProvider = MockWindowProvider()
        calculator = OcclusionCalculator(provider: mockProvider)
    }

    // MARK: - Helper

    func makeWindow(
        id: CGWindowID,
        frame: CGRect,
        zIndex: Int,
        processID: pid_t = 1,
        ownerName: String = "TestApp"
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            processID: processID,
            bundleIdentifier: "com.test.app",
            title: "Window \(id)",
            ownerName: ownerName,
            frame: frame,
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            zIndex: zIndex
        )
    }

    // MARK: - Tests

    func testNoOcclusion() async throws {
        // Single window, nothing covering it
        let window = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 0)
        mockProvider.mockWindows = [window]

        let result = try await calculator.calculate(for: 1)

        XCTAssertEqual(result.coveragePercentage, 0.0)
        XCTAssertEqual(result.visiblePercentage, 1.0)
        XCTAssertTrue(result.isFullyVisible)
        XCTAssertTrue(result.occludingWindows.isEmpty)
    }

    func testFullOcclusion() async throws {
        // Window fully covered by another
        let frontWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 200), zIndex: 0)
        let backWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        mockProvider.mockWindows = [frontWindow, backWindow]

        let result = try await calculator.calculate(for: 2)

        XCTAssertEqual(result.coveragePercentage, 1.0)
        XCTAssertEqual(result.visiblePercentage, 0.0)
        XCTAssertTrue(result.isFullyOccluded)
        XCTAssertEqual(result.occludingWindows.count, 1)
        XCTAssertEqual(result.occludingWindows.first?.id, 1)
    }

    func testPartialOcclusion() async throws {
        // Window 50% covered
        let frontWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 50, height: 100), zIndex: 0)
        let backWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        mockProvider.mockWindows = [frontWindow, backWindow]

        let result = try await calculator.calculate(for: 2)

        XCTAssertEqual(result.coveragePercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.visiblePercentage, 0.5, accuracy: 0.001)
        XCTAssertTrue(result.isOccluded(threshold: 0.4))
        XCTAssertFalse(result.isOccluded(threshold: 0.6))
    }

    func testOverlappingOccluders() async throws {
        // Two overlapping windows covering the back window
        // This tests that we don't double-count the overlap
        let front1 = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 60, height: 100), zIndex: 0)
        let front2 = makeWindow(id: 2, frame: CGRect(x: 40, y: 0, width: 60, height: 100), zIndex: 1)
        let backWindow = makeWindow(id: 3, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 2)
        mockProvider.mockWindows = [front1, front2, backWindow]

        let result = try await calculator.calculate(for: 3)

        // front1 covers x: 0-60, front2 covers x: 40-100
        // Together they cover x: 0-100 (full width)
        // Coverage should be 100%, not 120%
        XCTAssertEqual(result.coveragePercentage, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.occludingWindows.count, 2)
    }

    func testWindowNotFound() async {
        mockProvider.mockWindows = []

        do {
            _ = try await calculator.calculate(for: 999)
            XCTFail("Should have thrown windowNotFound error")
        } catch let error as OcclusionError {
            if case .windowNotFound(let id) = error {
                XCTAssertEqual(id, 999)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCoverageConvenience() async throws {
        let frontWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 25, height: 100), zIndex: 0)
        let backWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        mockProvider.mockWindows = [frontWindow, backWindow]

        let coverage = try await calculator.coverage(for: 2)

        XCTAssertEqual(coverage, 0.25, accuracy: 0.001)
    }

    func testIsOccludedConvenience() async throws {
        let frontWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 60, height: 100), zIndex: 0)
        let backWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        mockProvider.mockWindows = [frontWindow, backWindow]

        let isOccluded50 = try await calculator.isOccluded(2, threshold: 0.5)
        let isOccluded70 = try await calculator.isOccluded(2, threshold: 0.7)

        XCTAssertTrue(isOccluded50) // 60% > 50%
        XCTAssertFalse(isOccluded70) // 60% < 70%
    }

    func testWindowBehindNotCountedAsOccluder() async throws {
        // Windows behind the target should not count as occluders
        let backWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        let targetWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 0)
        mockProvider.mockWindows = [targetWindow, backWindow]

        let result = try await calculator.calculate(for: 2)

        XCTAssertEqual(result.coveragePercentage, 0.0)
        XCTAssertTrue(result.occludingWindows.isEmpty)
    }

    func testTransparentWindowsIgnored() async throws {
        // Windows with alpha = 0 should not occlude
        let transparentWindow = WindowInfo(
            id: 1,
            processID: 1,
            bundleIdentifier: "com.test.app",
            title: "Transparent",
            ownerName: "TestApp",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            layer: 0,
            alpha: 0.0,
            isOnScreen: true,
            zIndex: 0
        )
        let backWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 100, height: 100), zIndex: 1)
        mockProvider.mockWindows = [transparentWindow, backWindow]

        let result = try await calculator.calculate(for: 2)

        XCTAssertEqual(result.coveragePercentage, 0.0)
        XCTAssertTrue(result.occludingWindows.isEmpty)
    }
}
