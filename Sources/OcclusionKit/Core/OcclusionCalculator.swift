import Foundation
import CoreGraphics

/// The main calculation engine for window occlusion.
public actor OcclusionCalculator {
    /// The window provider to use
    private let provider: any WindowProvider

    /// Creates a new OcclusionCalculator
    /// - Parameter provider: The window provider to use (default: CGWindowProvider.shared)
    public init(provider: any WindowProvider = CGWindowProvider.shared) {
        self.provider = provider
    }

    // MARK: - Public API

    /// Calculates the occlusion for a specific window
    /// - Parameter windowID: The window ID to analyze
    /// - Returns: The occlusion result
    public func calculate(for windowID: CGWindowID) throws -> OcclusionResult {
        let windows = try provider.allWindows()

        guard let targetIndex = windows.firstIndex(where: { $0.id == windowID }) else {
            throw OcclusionError.windowNotFound(windowID)
        }

        let targetWindow = windows[targetIndex]
        return calculateOcclusion(for: targetWindow, allWindows: windows, targetIndex: targetIndex)
    }

    /// Calculates the occlusion for a WindowInfo
    /// - Parameter window: The window to analyze
    /// - Returns: The occlusion result
    public func calculate(for window: WindowInfo) throws -> OcclusionResult {
        let windows = try provider.allWindows()

        guard let targetIndex = windows.firstIndex(where: { $0.id == window.id }) else {
            throw OcclusionError.windowNotFound(window.id)
        }

        return calculateOcclusion(for: window, allWindows: windows, targetIndex: targetIndex)
    }

    /// Calculates occlusion for multiple windows
    /// - Parameter windowIDs: The window IDs to analyze
    /// - Returns: Array of occlusion results
    public func calculate(for windowIDs: [CGWindowID]) throws -> [OcclusionResult] {
        let windows = try provider.allWindows()
        var results: [OcclusionResult] = []

        for windowID in windowIDs {
            guard let targetIndex = windows.firstIndex(where: { $0.id == windowID }) else {
                continue
            }
            let target = windows[targetIndex]
            let result = calculateOcclusion(for: target, allWindows: windows, targetIndex: targetIndex)
            results.append(result)
        }

        return results
    }

    /// Returns the coverage percentage for a window (0.0 = visible, 1.0 = fully covered)
    /// - Parameter windowID: The window ID to analyze
    /// - Returns: The coverage percentage
    public func coverage(for windowID: CGWindowID) throws -> Double {
        try calculate(for: windowID).coveragePercentage
    }

    /// Checks if a window is occluded beyond a threshold
    /// - Parameters:
    ///   - windowID: The window ID to check
    ///   - threshold: The coverage threshold (default 0.5)
    /// - Returns: `true` if coverage exceeds threshold
    public func isOccluded(_ windowID: CGWindowID, threshold: Double = 0.5) throws -> Bool {
        try calculate(for: windowID).isOccluded(threshold: threshold)
    }

    // MARK: - Core Algorithm

    /// Calculates occlusion using the region subtraction algorithm
    private func calculateOcclusion(
        for targetWindow: WindowInfo,
        allWindows: [WindowInfo],
        targetIndex: Int
    ) -> OcclusionResult {
        let targetFrame = targetWindow.frame
        let targetArea = targetFrame.width * targetFrame.height

        // Handle edge cases
        guard targetArea > 0 else {
            return OcclusionResult(
                targetWindow: targetWindow,
                coveragePercentage: 1.0,
                occludingWindows: [],
                visibleRegions: []
            )
        }

        // Start with the target window as fully visible
        var visibleRegion = RegionSet(rect: targetFrame)
        var occludingWindows: [WindowInfo] = []

        // Windows are in z-order (front to back)
        // targetIndex is the position of our target window
        // All windows before targetIndex (lower indices) are in front
        let windowsAbove = allWindows.prefix(targetIndex)

        for window in windowsAbove {
            // Only consider windows that:
            // 1. Are on the same layer (ignore menu bar, dock, overlays, etc.)
            // 2. Have some opacity
            // 3. Are on screen
            guard window.layer == targetWindow.layer,
                  window.alpha > 0,
                  window.isOnScreen else {
                continue
            }

            // Check if this window intersects with our target
            let intersection = targetFrame.intersection(window.frame)
            if !intersection.isEmpty && !intersection.isNull {
                visibleRegion.subtract(window.frame)
                occludingWindows.append(window)
            }
        }

        // Calculate coverage
        let visibleArea = visibleRegion.area
        let coverage = 1.0 - (Double(visibleArea) / Double(targetArea))

        return OcclusionResult(
            targetWindow: targetWindow,
            coveragePercentage: max(0.0, min(1.0, coverage)),
            occludingWindows: occludingWindows,
            visibleRegions: visibleRegion.rectangles
        )
    }
}

// MARK: - Convenience Static Methods

extension OcclusionCalculator {
    /// Shared calculator instance using the default CGWindowProvider
    public static let shared = OcclusionCalculator()

    /// Calculates occlusion for a window (static convenience method)
    public static func calculate(for windowID: CGWindowID) async throws -> OcclusionResult {
        try await shared.calculate(for: windowID)
    }

    /// Returns the coverage percentage for a window (static convenience method)
    public static func coverage(for windowID: CGWindowID) async throws -> Double {
        try await shared.coverage(for: windowID)
    }

    /// Checks if a window is occluded (static convenience method)
    public static func isOccluded(_ windowID: CGWindowID, threshold: Double = 0.5) async throws -> Bool {
        try await shared.isOccluded(windowID, threshold: threshold)
    }
}
