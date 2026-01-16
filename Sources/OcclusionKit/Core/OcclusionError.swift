import Foundation
import CoreGraphics

/// Errors that can occur during occlusion operations.
public enum OcclusionError: Error, LocalizedError, Sendable {
    /// The specified window could not be found
    case windowNotFound(CGWindowID)

    /// The window data is invalid or malformed
    case invalidWindow(String)

    /// A system-level error occurred
    case systemError(String)

    /// Screen recording permission is required but not granted
    case permissionDenied

    /// No windows matched the query criteria
    case noMatchingWindows

    public var errorDescription: String? {
        switch self {
        case .windowNotFound(let id):
            return "Window with ID \(id) not found"
        case .invalidWindow(let reason):
            return "Invalid window: \(reason)"
        case .systemError(let message):
            return "System error: \(message)"
        case .permissionDenied:
            return "Screen recording permission is required. Grant access in System Preferences > Security & Privacy > Privacy > Screen Recording"
        case .noMatchingWindows:
            return "No windows matched the query criteria"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .windowNotFound:
            return "The window may have been closed. Try refreshing the window list."
        case .invalidWindow:
            return "Try querying for a different window."
        case .systemError:
            return "Try the operation again. If the problem persists, restart the application."
        case .permissionDenied:
            return "Open System Preferences, go to Security & Privacy > Privacy > Screen Recording, and enable access for this application."
        case .noMatchingWindows:
            return "Adjust your query criteria or ensure the target application is running."
        }
    }
}
