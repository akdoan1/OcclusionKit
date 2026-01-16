import Foundation
import CoreGraphics
import AppKit

/// macOS implementation of WindowProvider using CGWindowListCopyWindowInfo.
public final class CGWindowProvider: WindowProvider, @unchecked Sendable {
    /// Shared instance for convenience
    public static let shared = CGWindowProvider()

    /// Options for window list retrieval
    public let options: CGWindowListOption

    /// Creates a new CGWindowProvider
    /// - Parameter options: The window list options (default: on-screen only, excluding desktop)
    public init(options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]) {
        self.options = options
    }

    /// Returns all on-screen windows in z-order (front to back)
    public func allWindows() throws -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw OcclusionError.systemError("Failed to retrieve window list")
        }

        var windows: [WindowInfo] = []
        var zIndex = 0

        for windowDict in windowList {
            if let windowInfo = parseWindowInfo(from: windowDict, zIndex: zIndex) {
                windows.append(windowInfo)
                zIndex += 1
            }
        }

        return windows
    }

    /// Parses a window dictionary into a WindowInfo struct
    private func parseWindowInfo(from dict: [String: Any], zIndex: Int) -> WindowInfo? {
        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = dict[kCGWindowOwnerPID as String] as? Int32,
              let ownerName = dict[kCGWindowOwnerName as String] as? String,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }

        let frame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Skip windows with no area
        guard frame.width > 0 && frame.height > 0 else {
            return nil
        }

        let layer = dict[kCGWindowLayer as String] as? Int32 ?? 0
        let alpha = dict[kCGWindowAlpha as String] as? CGFloat ?? 1.0
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? true
        let title = dict[kCGWindowName as String] as? String

        // Get bundle identifier from PID
        let bundleIdentifier = bundleIdentifier(forPID: ownerPID)

        return WindowInfo(
            id: windowID,
            processID: ownerPID,
            bundleIdentifier: bundleIdentifier,
            title: title,
            ownerName: ownerName,
            frame: frame,
            layer: layer,
            alpha: alpha,
            isOnScreen: isOnScreen,
            zIndex: zIndex
        )
    }

    /// Gets the bundle identifier for a process ID
    private func bundleIdentifier(forPID pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
}

// MARK: - Screen Recording Permission (Optional)
//
// Screen Recording permission is OPTIONAL for OcclusionKit.
//
// WITHOUT permission (works out of the box):
// - Window bounds/frames (occlusion calculation)
// - Window layer, alpha, on-screen status
// - Process ID and owner name
// - All occlusion APIs: isOccluded(), coverage(), calculate()
// - Query by: process(), owner(), windowID(), layer(), minArea(), etc.
//
// WITH permission (requires user consent):
// - Window titles from other apps (title is nil without permission)
// - Query by: title(), titleContains(), titleMatching()
// - Note: bundle() works via NSRunningApplication, not CGWindowList

extension CGWindowProvider {
    /// Checks if Screen Recording permission is granted.
    ///
    /// **Important**: This permission is OPTIONAL. Core occlusion features work without it.
    ///
    /// Only needed if you want to:
    /// - Read window titles from other applications
    /// - Use `titleContains()` or `titleMatching()` queries on other apps' windows
    ///
    /// - Returns: `true` if permission is granted, `false` or `nil` if denied/unknown
    public static var hasScreenRecordingPermission: Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Check if we can read window names from other processes
        // Without permission, window names will be nil for other apps
        for dict in windowList {
            if let ownerPID = dict[kCGWindowOwnerPID as String] as? Int32,
               ownerPID != ProcessInfo.processInfo.processIdentifier {
                // Found a window from another process
                // If we can read its name, we have permission
                if dict[kCGWindowName as String] != nil {
                    return true
                }
            }
        }

        // Could not confirm permission - may or may not have it
        // (e.g., no other windows have titles, or only our windows visible)
        return false
    }

    /// Requests Screen Recording permission by triggering the system prompt.
    ///
    /// **Important**: This permission is OPTIONAL. Only call this if you need window titles.
    ///
    /// Returns immediately - the user will see a system dialog.
    /// The app may need to be restarted for the permission to take effect.
    public static func requestScreenRecordingPermission() {
        // Creating a screen capture triggers the permission prompt
        _ = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }
}
