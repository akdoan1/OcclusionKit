import XCTest
@testable import OcclusionKit

/// Integration tests that use the real CGWindowProvider.
/// These tests verify the library works with actual macOS window APIs.
/// Note: These tests may require Screen Recording permission to get full window info.
final class IntegrationTests: XCTestCase {

    /// Test that we can get the list of windows from the system
    func testCanGetWindowList() throws {
        let windows = try OcclusionKit.allWindows()

        // There should be at least some windows on the system
        XCTAssertFalse(windows.isEmpty, "Should have at least one window")

        // Each window should have valid properties
        for window in windows {
            XCTAssertGreaterThan(window.id, 0)
            XCTAssertFalse(window.ownerName.isEmpty)
            XCTAssertGreaterThan(window.frame.width, 0)
            XCTAssertGreaterThan(window.frame.height, 0)
        }
    }

    /// Test that windows are returned in z-order
    func testWindowsInZOrder() throws {
        let windows = try OcclusionKit.allWindows()

        // zIndex should be sequential starting from 0
        for (index, window) in windows.enumerated() {
            XCTAssertEqual(window.zIndex, index, "Window zIndex should match array position")
        }
    }

    /// Test that we can calculate occlusion for a real window
    func testCanCalculateOcclusion() async throws {
        let windows = try OcclusionKit.allWindows()
        guard let firstWindow = windows.first else {
            throw XCTSkip("No windows available for testing")
        }

        let result = try await OcclusionKit.calculate(for: firstWindow.id)

        // Result should be valid
        XCTAssertEqual(result.targetWindow.id, firstWindow.id)
        XCTAssertGreaterThanOrEqual(result.coveragePercentage, 0.0)
        XCTAssertLessThanOrEqual(result.coveragePercentage, 1.0)
        XCTAssertEqual(result.visiblePercentage, 1.0 - result.coveragePercentage, accuracy: 0.001)
    }

    /// Test that we can calculate occlusion for the frontmost window
    func testFrontmostWindowOcclusion() async throws {
        let windows = try OcclusionKit.allWindows()
            .filter { $0.isNormalLayer } // Only normal layer windows

        guard let frontmost = windows.first else {
            throw XCTSkip("No normal layer windows available")
        }

        let result = try await OcclusionKit.calculate(for: frontmost.id)

        // Just verify we get a valid result
        // (Frontmost window may still be partially occluded by menu bar, overlays, etc.)
        XCTAssertGreaterThanOrEqual(result.coveragePercentage, 0.0)
        XCTAssertLessThanOrEqual(result.coveragePercentage, 1.0)
        XCTAssertEqual(result.targetWindow.id, frontmost.id)
    }

    /// Test query builder works with real windows
    func testQueryBuilder() async throws {
        // Query all windows with minimum area
        let windows = try await OcclusionKit.query()
            .minArea(100)
            .normalLayer()
            .windows()

        // Should find some windows
        XCTAssertFalse(windows.isEmpty, "Should find windows meeting criteria")

        // All should be normal layer and have area >= 100
        for window in windows {
            XCTAssertTrue(window.isNormalLayer)
            XCTAssertGreaterThanOrEqual(window.area, 100)
        }
    }

    /// Test WindowInfo properties
    func testWindowInfoProperties() throws {
        let windows = try OcclusionKit.allWindows()
        guard let window = windows.first else {
            throw XCTSkip("No windows available")
        }

        // Test computed properties
        XCTAssertEqual(window.area, window.frame.width * window.frame.height)
        XCTAssertEqual(window.isNormalLayer, window.layer == 0)

        // Test description doesn't crash
        let description = window.description
        XCTAssertFalse(description.isEmpty)
    }

    /// Test OcclusionResult computed properties
    func testOcclusionResultProperties() async throws {
        let windows = try OcclusionKit.allWindows()
        guard let window = windows.first else {
            throw XCTSkip("No windows available")
        }

        let result = try await OcclusionKit.calculate(for: window.id)

        // Test threshold methods
        let threshold = result.coveragePercentage
        XCTAssertTrue(result.isOccluded(threshold: threshold - 0.01) || threshold == 0)
        XCTAssertFalse(result.isOccluded(threshold: threshold + 0.01) && threshold < 1)

        // Test description
        let description = result.description
        XCTAssertFalse(description.isEmpty)
    }

    /// Test error handling for non-existent window
    func testWindowNotFoundError() async {
        // Use a very high window ID that's unlikely to exist
        let nonExistentID: CGWindowID = 999999999

        do {
            _ = try await OcclusionKit.calculate(for: nonExistentID)
            XCTFail("Should throw windowNotFound error")
        } catch let error as OcclusionError {
            if case .windowNotFound(let id) = error {
                XCTAssertEqual(id, nonExistentID)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// Test permission check doesn't crash
    func testPermissionCheck() {
        // Just verify this doesn't crash
        // Note: Screen Recording permission is OPTIONAL - core features work without it
        let hasPermission = OcclusionKit.hasScreenRecordingPermission
        // We can't assert the value since it depends on system settings
        _ = hasPermission
    }
}
