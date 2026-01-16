import Foundation
import CoreGraphics

/// An AsyncSequence that yields occlusion results for a window.
@available(macOS 10.15, *)
public struct OcclusionStream: AsyncSequence, Sendable {
    public typealias Element = OcclusionResult

    private let windowID: CGWindowID
    private let interval: TimeInterval
    private let calculator: OcclusionCalculator
    private let emitOnlyChanges: Bool

    /// Creates an async stream for window occlusion changes
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: The polling interval (default: 0.5 seconds)
    ///   - calculator: The calculator to use (default: shared)
    ///   - emitOnlyChanges: If true, only emit when coverage changes (default: true)
    public init(
        windowID: CGWindowID,
        interval: TimeInterval = 0.5,
        calculator: OcclusionCalculator = .shared,
        emitOnlyChanges: Bool = true
    ) {
        self.windowID = windowID
        self.interval = interval
        self.calculator = calculator
        self.emitOnlyChanges = emitOnlyChanges
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            windowID: windowID,
            interval: interval,
            calculator: calculator,
            emitOnlyChanges: emitOnlyChanges
        )
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let windowID: CGWindowID
        private let interval: TimeInterval
        private let calculator: OcclusionCalculator
        private let emitOnlyChanges: Bool
        private var lastCoverage: Double?
        private var isFinished = false

        init(
            windowID: CGWindowID,
            interval: TimeInterval,
            calculator: OcclusionCalculator,
            emitOnlyChanges: Bool
        ) {
            self.windowID = windowID
            self.interval = interval
            self.calculator = calculator
            self.emitOnlyChanges = emitOnlyChanges
        }

        public mutating func next() async -> OcclusionResult? {
            guard !isFinished else { return nil }

            // Check for cancellation
            guard !Task.isCancelled else {
                isFinished = true
                return nil
            }

            do {
                while true {
                    let result = try await calculator.calculate(for: windowID)

                    let shouldEmit = !emitOnlyChanges || lastCoverage != result.coveragePercentage
                    lastCoverage = result.coveragePercentage

                    if shouldEmit {
                        return result
                    }

                    // Wait for next interval
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                    // Check for cancellation again
                    if Task.isCancelled {
                        isFinished = true
                        return nil
                    }
                }
            } catch is CancellationError {
                isFinished = true
                return nil
            } catch {
                // Window not found or other error - stop iteration
                isFinished = true
                return nil
            }
        }
    }
}

// MARK: - Filtered Streams

@available(macOS 10.15, *)
extension OcclusionStream {
    /// Returns a stream that only yields when the window is occluded beyond the threshold
    public func whenOccluded(threshold: Double = 0.5) -> AsyncFilterSequence<OcclusionStream> {
        self.filter { $0.isOccluded(threshold: threshold) }
    }

    /// Returns a stream that only yields when the window is visible beyond the threshold
    public func whenVisible(threshold: Double = 0.5) -> AsyncFilterSequence<OcclusionStream> {
        self.filter { $0.isVisible(threshold: threshold) }
    }

    /// Returns a stream of coverage percentages only
    public func coverageOnly() -> AsyncMapSequence<OcclusionStream, Double> {
        self.map(\.coveragePercentage)
    }

    /// Returns a stream of visibility percentages only
    public func visibilityOnly() -> AsyncMapSequence<OcclusionStream, Double> {
        self.map(\.visiblePercentage)
    }
}
