import Foundation
import CoreGraphics

/// Information about a window on screen.
public struct WindowInfo: Sendable, Identifiable, Hashable {
    /// The unique window identifier (CGWindowID)
    public let id: CGWindowID

    /// The process ID of the window's owner
    public let processID: pid_t

    /// The bundle identifier of the window's owner (if available)
    public let bundleIdentifier: String?

    /// The window title (if available)
    public let title: String?

    /// The name of the application that owns this window
    public let ownerName: String

    /// The window's frame in screen coordinates
    public let frame: CGRect

    /// The window layer (0 = normal windows, negative = below, positive = above)
    public let layer: Int32

    /// The window's alpha/opacity value (0.0 to 1.0)
    public let alpha: CGFloat

    /// Whether the window is currently on screen
    public let isOnScreen: Bool

    /// The z-order index (0 = frontmost visible window)
    public let zIndex: Int

    /// Creates a new WindowInfo instance
    public init(
        id: CGWindowID,
        processID: pid_t,
        bundleIdentifier: String?,
        title: String?,
        ownerName: String,
        frame: CGRect,
        layer: Int32,
        alpha: CGFloat,
        isOnScreen: Bool,
        zIndex: Int
    ) {
        self.id = id
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.ownerName = ownerName
        self.frame = frame
        self.layer = layer
        self.alpha = alpha
        self.isOnScreen = isOnScreen
        self.zIndex = zIndex
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Convenience Properties

extension WindowInfo {
    /// The window's area in square points
    public var area: CGFloat {
        frame.width * frame.height
    }

    /// Whether this is a normal layer window (layer == 0)
    public var isNormalLayer: Bool {
        layer == 0
    }

    /// Whether the window is visible (on screen, has area, and has some opacity)
    public var isVisible: Bool {
        isOnScreen && area > 0 && alpha > 0
    }
}

// MARK: - CustomStringConvertible

extension WindowInfo: CustomStringConvertible {
    public var description: String {
        let titleStr = title.map { "\"\($0)\"" } ?? "untitled"
        return "WindowInfo(id: \(id), owner: \(ownerName), title: \(titleStr), frame: \(frame))"
    }
}
