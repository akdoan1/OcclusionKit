import Foundation
import CoreGraphics

/// A fluent query builder for finding and analyzing windows.
public struct WindowQuery: Sendable {
    private let provider: any WindowProvider
    private let calculator: OcclusionCalculator
    private var matchers: [WindowMatcher]

    /// Creates a new query with the default provider
    public init() {
        self.provider = CGWindowProvider.shared
        self.calculator = OcclusionCalculator.shared
        self.matchers = []
    }

    /// Creates a new query with a custom provider
    public init(provider: any WindowProvider, calculator: OcclusionCalculator) {
        self.provider = provider
        self.calculator = calculator
        self.matchers = []
    }

    /// Internal initializer for chaining
    private init(
        provider: any WindowProvider,
        calculator: OcclusionCalculator,
        matchers: [WindowMatcher]
    ) {
        self.provider = provider
        self.calculator = calculator
        self.matchers = matchers
    }

    // MARK: - Chainable Filters

    /// Filter by process ID
    public func process(_ pid: pid_t) -> WindowQuery {
        addMatcher(.process(pid))
    }

    /// Filter by exact bundle identifier
    public func bundle(_ identifier: String) -> WindowQuery {
        addMatcher(.bundle(identifier))
    }

    /// Filter by bundle identifier pattern (supports * wildcard)
    public func bundleMatching(_ pattern: String) -> WindowQuery {
        addMatcher(.bundleMatching(pattern))
    }

    /// Filter by exact title
    public func title(_ title: String) -> WindowQuery {
        addMatcher(.title(title))
    }

    /// Filter by title containing substring
    public func titleContains(_ substring: String) -> WindowQuery {
        addMatcher(.titleContains(substring))
    }

    /// Filter by title regex pattern
    public func titleMatching(_ pattern: String) -> WindowQuery {
        addMatcher(.titleMatching(pattern))
    }

    /// Filter by exact owner name
    public func owner(_ name: String) -> WindowQuery {
        addMatcher(.owner(name))
    }

    /// Filter by owner name containing substring
    public func ownerContains(_ substring: String) -> WindowQuery {
        addMatcher(.ownerContains(substring))
    }

    /// Filter by window ID
    public func windowID(_ id: CGWindowID) -> WindowQuery {
        addMatcher(.windowID(id))
    }

    /// Filter by minimum area
    public func minArea(_ area: CGFloat) -> WindowQuery {
        addMatcher(.minArea(area))
    }

    /// Filter by maximum area
    public func maxArea(_ area: CGFloat) -> WindowQuery {
        addMatcher(.maxArea(area))
    }

    /// Filter by layer
    public func layer(_ layer: Int32) -> WindowQuery {
        addMatcher(.layer(layer))
    }

    /// Filter to normal layer windows only
    public func normalLayer() -> WindowQuery {
        addMatcher(.normalLayer)
    }

    /// Filter to on-screen windows only
    public func onScreen() -> WindowQuery {
        addMatcher(.onScreen)
    }

    /// Filter to visible windows only (on screen, has area, has opacity)
    public func visible() -> WindowQuery {
        addMatcher(.visible)
    }

    /// Add a custom filter predicate
    public func filter(_ predicate: @escaping @Sendable (WindowInfo) -> Bool) -> WindowQuery {
        addMatcher(WindowMatcher(predicate))
    }

    /// Add a matcher
    public func matching(_ matcher: WindowMatcher) -> WindowQuery {
        addMatcher(matcher)
    }

    private func addMatcher(_ matcher: WindowMatcher) -> WindowQuery {
        var newMatchers = matchers
        newMatchers.append(matcher)
        return WindowQuery(provider: provider, calculator: calculator, matchers: newMatchers)
    }

    // MARK: - Terminal Operations

    /// Execute the query and return matching windows
    public func windows() async throws -> [WindowInfo] {
        let allWindows = try provider.allWindows()
        return allWindows.filter { window in
            matchers.allSatisfy { $0.matches(window) }
        }
    }

    /// Execute the query and return occlusion results for matching windows
    public func results() async throws -> [OcclusionResult] {
        let matchingWindows = try await windows()
        var results: [OcclusionResult] = []

        for window in matchingWindows {
            let result = try await calculator.calculate(for: window)
            results.append(result)
        }

        return results
    }

    /// Execute the query and return the first matching result
    public func first() async throws -> OcclusionResult? {
        let matchingWindows = try await windows()
        guard let window = matchingWindows.first else {
            return nil
        }
        return try await calculator.calculate(for: window)
    }

    /// Execute the query and return the first matching window
    public func firstWindow() async throws -> WindowInfo? {
        try await windows().first
    }

    /// Execute the query and return the count of matching windows
    public func count() async throws -> Int {
        try await windows().count
    }

    /// Execute the query and check if any windows match
    public func exists() async throws -> Bool {
        try await count() > 0
    }
}
