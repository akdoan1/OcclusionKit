import Foundation
import CoreGraphics

/// OcclusionKit - A Swift library for macOS window occlusion detection.
///
/// Provides accurate detection of window coverage by other windows,
/// including exact coverage percentages and reactive observation APIs.
///
/// ## Quick Start
///
/// ```swift
/// import OcclusionKit
///
/// // Check if a window is mostly hidden
/// let isHidden = try await OcclusionKit.isOccluded(windowID, threshold: 0.5)
///
/// // Get exact coverage percentage
/// let coverage = try await OcclusionKit.coverage(for: windowID)
/// print("Window is \(Int(coverage * 100))% covered")
///
/// // Get full analysis
/// let result = try await OcclusionKit.calculate(for: windowID)
/// print("Covered by \(result.occludingWindows.count) windows")
/// ```
///
/// ## Query Builder
///
/// ```swift
/// // Find Terminal windows
/// let results = try await OcclusionKit
///     .query()
///     .bundle("com.apple.Terminal")
///     .results()
///
/// // Find by title
/// let window = try await OcclusionKit
///     .query()
///     .titleContains("Claude")
///     .first()
/// ```
///
/// ## Observation
///
/// ```swift
/// // Using AsyncSequence
/// for await result in OcclusionKit.stream(for: windowID) {
///     updateUI(visible: result.visiblePercentage)
/// }
///
/// // Using Combine
/// OcclusionKit.publisher(for: windowID)
///     .sink { result in print("Coverage: \(result.coveragePercentage)") }
///     .store(in: &cancellables)
/// ```
public enum OcclusionKit {
    // MARK: - Simple Checks

    /// Check if a window is occluded beyond the threshold
    /// - Parameters:
    ///   - windowID: The window to check
    ///   - threshold: Coverage threshold (0.0 to 1.0, default 0.5)
    /// - Returns: `true` if coverage exceeds threshold
    public static func isOccluded(_ windowID: CGWindowID, threshold: Double = 0.5) async throws -> Bool {
        try await OcclusionCalculator.shared.isOccluded(windowID, threshold: threshold)
    }

    /// Get the coverage percentage for a window
    /// - Parameter windowID: The window to analyze
    /// - Returns: Coverage percentage (0.0 = fully visible, 1.0 = fully covered)
    public static func coverage(for windowID: CGWindowID) async throws -> Double {
        try await OcclusionCalculator.shared.coverage(for: windowID)
    }

    /// Get full occlusion analysis for a window
    /// - Parameter windowID: The window to analyze
    /// - Returns: Complete occlusion result with coverage, occluding windows, and visible regions
    public static func calculate(for windowID: CGWindowID) async throws -> OcclusionResult {
        try await OcclusionCalculator.shared.calculate(for: windowID)
    }

    // MARK: - Query Builder

    /// Start a query to find and analyze windows
    /// - Returns: A new WindowQuery builder
    public static func query() -> WindowQuery {
        WindowQuery()
    }

    // MARK: - All Windows

    /// Get all visible windows in z-order
    /// - Returns: Array of window info, front to back
    public static func allWindows() throws -> [WindowInfo] {
        try CGWindowProvider.shared.allWindows()
    }

    /// Get a specific window by ID
    /// - Parameter windowID: The window ID
    /// - Returns: Window info or nil if not found
    public static func window(_ windowID: CGWindowID) throws -> WindowInfo? {
        try CGWindowProvider.shared.window(id: windowID)
    }

    // MARK: - Reactive Observation

    /// Create a Combine publisher for occlusion changes
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: Polling interval in seconds (default 0.5)
    /// - Returns: A publisher that emits OcclusionResult values
    @available(macOS 10.15, *)
    public static func publisher(
        for windowID: CGWindowID,
        interval: TimeInterval = 0.5
    ) -> OcclusionPublisher {
        OcclusionPublisher(windowID: windowID, interval: interval)
    }

    /// Create an AsyncSequence for occlusion changes
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: Polling interval in seconds (default 0.5)
    /// - Returns: An async sequence that yields OcclusionResult values
    @available(macOS 10.15, *)
    public static func stream(
        for windowID: CGWindowID,
        interval: TimeInterval = 0.5
    ) -> OcclusionStream {
        OcclusionStream(windowID: windowID, interval: interval)
    }

    /// Create a callback-based observer for occlusion changes
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: Polling interval in seconds (default 0.5)
    ///   - handler: Called when occlusion changes
    /// - Returns: An observer (call `.start()` to begin, `.stop()` to end)
    public static func observer(
        for windowID: CGWindowID,
        interval: TimeInterval = 0.5,
        handler: @escaping @Sendable (OcclusionResult) -> Void
    ) -> OcclusionObserver {
        OcclusionObserver(windowID: windowID, interval: interval, handler: handler)
    }

    // MARK: - Permissions (Optional)
    //
    // Screen Recording permission is OPTIONAL for OcclusionKit.
    // Core occlusion features (isOccluded, coverage, calculate) work without it.
    //
    // Only needed for: reading window titles from other apps

    /// Whether Screen Recording permission is granted.
    ///
    /// **This permission is OPTIONAL.** Core features work without it:
    /// - `isOccluded()`, `coverage()`, `calculate()` - all work
    /// - `query().process()`, `query().owner()` - work
    /// - `query().bundle()` - works (uses NSRunningApplication)
    ///
    /// Only needed for:
    /// - `query().title()`, `query().titleContains()`, `query().titleMatching()`
    ///   when targeting other apps' windows
    public static var hasScreenRecordingPermission: Bool {
        CGWindowProvider.hasScreenRecordingPermission
    }

    /// Request Screen Recording permission (shows system dialog).
    ///
    /// **This permission is OPTIONAL.** Only call if you need window titles from other apps.
    public static func requestScreenRecordingPermission() {
        CGWindowProvider.requestScreenRecordingPermission()
    }
}

// MARK: - Type Aliases for Convenience

/// A window identifier
public typealias WindowID = CGWindowID
