import Foundation
import CoreGraphics

/// Callback-based observer for window occlusion changes.
public final class OcclusionObserver: @unchecked Sendable {
    /// The type of callback for occlusion changes
    public typealias Handler = @Sendable (OcclusionResult) -> Void

    private let windowID: CGWindowID
    private let calculator: OcclusionCalculator
    private let interval: TimeInterval
    private let handler: Handler

    private var timer: Timer?
    private var isStarting = false
    private var lastResult: OcclusionResult?
    private let lock = NSLock()

    /// Creates a new observer for the given window
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: The polling interval in seconds (default: 0.5)
    ///   - calculator: The calculator to use (default: shared)
    ///   - handler: Called when occlusion changes
    public init(
        windowID: CGWindowID,
        interval: TimeInterval = 0.5,
        calculator: OcclusionCalculator = .shared,
        handler: @escaping Handler
    ) {
        self.windowID = windowID
        self.interval = interval
        self.calculator = calculator
        self.handler = handler
    }

    deinit {
        stop()
    }

    /// Starts observing occlusion changes
    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard timer == nil && !isStarting else { return }
        isStarting = true

        // Run on main thread for Timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            // Double-check we haven't been stopped or already started
            guard self.timer == nil && self.isStarting else {
                self.isStarting = false
                return
            }

            self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
                self?.checkOcclusion()
            }
            self.isStarting = false

            // Fire immediately (outside lock to avoid deadlock)
            self.lock.unlock()
            self.checkOcclusion()
            self.lock.lock()
        }
    }

    /// Stops observing
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        isStarting = false
        timer?.invalidate()
        timer = nil
    }

    /// Whether the observer is currently running
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timer != nil || isStarting
    }

    private func checkOcclusion() {
        Task {
            do {
                let result = try await calculator.calculate(for: windowID)

                // Dispatch to main to safely access lock and call handler
                await MainActor.run {
                    lock.lock()
                    let changed = lastResult?.coveragePercentage != result.coveragePercentage
                    lastResult = result
                    lock.unlock()

                    if changed {
                        handler(result)
                    }
                }
            } catch {
                // Window may have been closed - stop observing
                await MainActor.run {
                    stop()
                }
            }
        }
    }
}

// MARK: - Factory Method

extension OcclusionObserver {
    /// Creates and starts an observer
    /// - Parameters:
    ///   - windowID: The window to observe
    ///   - interval: The polling interval
    ///   - handler: Called when occlusion changes
    /// - Returns: A running observer (stop with `.stop()`)
    public static func observe(
        _ windowID: CGWindowID,
        interval: TimeInterval = 0.5,
        handler: @escaping Handler
    ) -> OcclusionObserver {
        let observer = OcclusionObserver(windowID: windowID, interval: interval, handler: handler)
        observer.start()
        return observer
    }
}
