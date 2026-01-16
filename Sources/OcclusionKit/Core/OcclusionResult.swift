import Foundation
import CoreGraphics

/// The result of an occlusion calculation for a window.
public struct OcclusionResult: Sendable {
    /// The window that was analyzed
    public let targetWindow: WindowInfo

    /// The percentage of the window that is covered (0.0 = fully visible, 1.0 = fully covered)
    public let coveragePercentage: Double

    /// The windows that are occluding (covering) the target window, in z-order
    public let occludingWindows: [WindowInfo]

    /// The visible (uncovered) regions of the target window
    public let visibleRegions: [CGRect]

    /// Creates a new OcclusionResult
    public init(
        targetWindow: WindowInfo,
        coveragePercentage: Double,
        occludingWindows: [WindowInfo],
        visibleRegions: [CGRect]
    ) {
        self.targetWindow = targetWindow
        self.coveragePercentage = min(1.0, max(0.0, coveragePercentage))
        self.occludingWindows = occludingWindows
        self.visibleRegions = visibleRegions
    }

    /// The percentage of the window that is visible (1.0 - coveragePercentage)
    public var visiblePercentage: Double {
        1.0 - coveragePercentage
    }

    /// The total visible area in square points
    public var visibleArea: CGFloat {
        visibleRegions.reduce(0) { $0 + $1.width * $1.height }
    }

    /// The total covered area in square points
    public var coveredArea: CGFloat {
        targetWindow.area - visibleArea
    }

    /// Checks if the window is occluded beyond the given threshold
    /// - Parameter threshold: The coverage percentage threshold (0.0 to 1.0, default 0.5)
    /// - Returns: `true` if coverage exceeds the threshold
    public func isOccluded(threshold: Double = 0.5) -> Bool {
        coveragePercentage > threshold
    }

    /// Checks if the window is visible beyond the given threshold
    /// - Parameter threshold: The visibility percentage threshold (0.0 to 1.0, default 0.5)
    /// - Returns: `true` if visibility exceeds the threshold
    public func isVisible(threshold: Double = 0.5) -> Bool {
        visiblePercentage > threshold
    }

    /// Whether the window is fully visible (no occlusion)
    public var isFullyVisible: Bool {
        coveragePercentage == 0.0
    }

    /// Whether the window is fully occluded
    public var isFullyOccluded: Bool {
        coveragePercentage >= 1.0
    }
}

// MARK: - CustomStringConvertible

extension OcclusionResult: CustomStringConvertible {
    public var description: String {
        let coveragePct = Int(coveragePercentage * 100)
        let occluderCount = occludingWindows.count
        return "OcclusionResult(\(targetWindow.ownerName): \(coveragePct)% covered by \(occluderCount) window(s))"
    }
}

// MARK: - Equatable

extension OcclusionResult: Equatable {
    public static func == (lhs: OcclusionResult, rhs: OcclusionResult) -> Bool {
        lhs.targetWindow.id == rhs.targetWindow.id &&
        lhs.coveragePercentage == rhs.coveragePercentage
    }
}
