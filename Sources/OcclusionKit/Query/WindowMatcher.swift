import Foundation
import CoreGraphics

/// A predicate for matching windows.
public struct WindowMatcher: Sendable {
    /// The matching function
    public let matches: @Sendable (WindowInfo) -> Bool

    /// Creates a new matcher with the given predicate
    public init(_ predicate: @escaping @Sendable (WindowInfo) -> Bool) {
        self.matches = predicate
    }

    /// Combines this matcher with another using AND logic
    public func and(_ other: WindowMatcher) -> WindowMatcher {
        WindowMatcher { window in
            self.matches(window) && other.matches(window)
        }
    }

    /// Combines this matcher with another using OR logic
    public func or(_ other: WindowMatcher) -> WindowMatcher {
        WindowMatcher { window in
            self.matches(window) || other.matches(window)
        }
    }

    /// Negates this matcher
    public var not: WindowMatcher {
        WindowMatcher { window in
            !self.matches(window)
        }
    }
}

// MARK: - Built-in Matchers

extension WindowMatcher {
    /// Matches all windows
    public static let all = WindowMatcher { _ in true }

    /// Matches no windows
    public static let none = WindowMatcher { _ in false }

    /// Matches windows by process ID
    public static func process(_ pid: pid_t) -> WindowMatcher {
        WindowMatcher { $0.processID == pid }
    }

    /// Matches windows by exact bundle identifier
    public static func bundle(_ identifier: String) -> WindowMatcher {
        WindowMatcher { $0.bundleIdentifier == identifier }
    }

    /// Matches windows by bundle identifier pattern (supports * wildcard)
    public static func bundleMatching(_ pattern: String) -> WindowMatcher {
        let regex = patternToRegex(pattern)
        return WindowMatcher { window in
            guard let bundleID = window.bundleIdentifier else { return false }
            return bundleID.range(of: regex, options: .regularExpression) != nil
        }
    }

    /// Matches windows by exact title
    public static func title(_ title: String) -> WindowMatcher {
        WindowMatcher { $0.title == title }
    }

    /// Matches windows with title containing substring
    public static func titleContains(_ substring: String) -> WindowMatcher {
        WindowMatcher { window in
            window.title?.localizedCaseInsensitiveContains(substring) ?? false
        }
    }

    /// Matches windows by title regex pattern
    public static func titleMatching(_ pattern: String) -> WindowMatcher {
        WindowMatcher { window in
            guard let title = window.title else { return false }
            return title.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Matches windows by owner name
    public static func owner(_ name: String) -> WindowMatcher {
        WindowMatcher { $0.ownerName == name }
    }

    /// Matches windows by owner name containing substring
    public static func ownerContains(_ substring: String) -> WindowMatcher {
        WindowMatcher { $0.ownerName.localizedCaseInsensitiveContains(substring) }
    }

    /// Matches windows by window ID
    public static func windowID(_ id: CGWindowID) -> WindowMatcher {
        WindowMatcher { $0.id == id }
    }

    /// Matches windows with area >= minimum
    public static func minArea(_ area: CGFloat) -> WindowMatcher {
        WindowMatcher { $0.area >= area }
    }

    /// Matches windows with area <= maximum
    public static func maxArea(_ area: CGFloat) -> WindowMatcher {
        WindowMatcher { $0.area <= area }
    }

    /// Matches windows on a specific layer
    public static func layer(_ layer: Int32) -> WindowMatcher {
        WindowMatcher { $0.layer == layer }
    }

    /// Matches normal layer windows (layer == 0)
    public static let normalLayer = WindowMatcher { $0.isNormalLayer }

    /// Matches windows that are on screen
    public static let onScreen = WindowMatcher { $0.isOnScreen }

    /// Matches windows with alpha > 0
    public static let visible = WindowMatcher { $0.isVisible }

    /// Converts a simple wildcard pattern to regex
    private static func patternToRegex(_ pattern: String) -> String {
        var regex = NSRegularExpression.escapedPattern(for: pattern)
        regex = regex.replacingOccurrences(of: "\\*", with: ".*")
        regex = regex.replacingOccurrences(of: "\\?", with: ".")
        return "^" + regex + "$"
    }
}
