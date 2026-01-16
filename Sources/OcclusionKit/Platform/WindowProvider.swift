import Foundation
import CoreGraphics

/// Protocol for providing window information.
/// Abstracted to allow for testing and potential cross-platform support.
public protocol WindowProvider: Sendable {
    /// Returns all on-screen windows in z-order (front to back)
    func allWindows() throws -> [WindowInfo]

    /// Returns a specific window by ID
    func window(id: CGWindowID) throws -> WindowInfo?

    /// Returns windows for a specific process
    func windows(forProcess pid: pid_t) throws -> [WindowInfo]

    /// Returns windows matching a predicate
    func windows(matching predicate: @Sendable (WindowInfo) -> Bool) throws -> [WindowInfo]
}

// MARK: - Default Implementations

extension WindowProvider {
    public func window(id: CGWindowID) throws -> WindowInfo? {
        try allWindows().first { $0.id == id }
    }

    public func windows(forProcess pid: pid_t) throws -> [WindowInfo] {
        try allWindows().filter { $0.processID == pid }
    }

    public func windows(matching predicate: @Sendable (WindowInfo) -> Bool) throws -> [WindowInfo] {
        try allWindows().filter(predicate)
    }
}
