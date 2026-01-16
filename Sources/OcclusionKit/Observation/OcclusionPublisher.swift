import Foundation
import CoreGraphics
import Combine

/// A Combine publisher that emits occlusion results for a window.
@available(macOS 10.15, *)
public struct OcclusionPublisher: Publisher {
    public typealias Output = OcclusionResult
    public typealias Failure = OcclusionError

    private let windowID: CGWindowID
    private let interval: TimeInterval
    private let calculator: OcclusionCalculator
    private let emitOnlyChanges: Bool

    /// Creates a publisher for window occlusion changes
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

    public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == Failure, S.Input == Output {
        let subscription = OcclusionSubscription(
            subscriber: subscriber,
            windowID: windowID,
            interval: interval,
            calculator: calculator,
            emitOnlyChanges: emitOnlyChanges
        )
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - Subscription

@available(macOS 10.15, *)
private final class OcclusionSubscription<S: Subscriber>: Subscription
where S.Input == OcclusionResult, S.Failure == OcclusionError {
    private var subscriber: S?
    private let windowID: CGWindowID
    private let interval: TimeInterval
    private let calculator: OcclusionCalculator
    private let emitOnlyChanges: Bool

    private var timer: Timer?
    private var lastCoverage: Double?
    private var demand: Subscribers.Demand = .none

    init(
        subscriber: S,
        windowID: CGWindowID,
        interval: TimeInterval,
        calculator: OcclusionCalculator,
        emitOnlyChanges: Bool
    ) {
        self.subscriber = subscriber
        self.windowID = windowID
        self.interval = interval
        self.calculator = calculator
        self.emitOnlyChanges = emitOnlyChanges
    }

    func request(_ demand: Subscribers.Demand) {
        self.demand += demand

        if timer == nil && demand > .none {
            startTimer()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        subscriber = nil
    }

    private func startTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
                self?.tick()
            }

            // Fire immediately
            self.tick()
        }
    }

    private func tick() {
        guard demand > .none, let subscriber = subscriber else { return }

        Task {
            do {
                let result = try await calculator.calculate(for: windowID)

                await MainActor.run {
                    let shouldEmit = !emitOnlyChanges || lastCoverage != result.coveragePercentage
                    lastCoverage = result.coveragePercentage

                    if shouldEmit {
                        demand -= 1
                        let additionalDemand = subscriber.receive(result)
                        demand += additionalDemand
                    }
                }
            } catch let error as OcclusionError {
                subscriber.receive(completion: .failure(error))
                cancel()
            } catch {
                subscriber.receive(completion: .failure(.systemError(error.localizedDescription)))
                cancel()
            }
        }
    }
}

// MARK: - Convenience Extensions

@available(macOS 10.15, *)
extension OcclusionPublisher {
    /// Filters to only emit when the window becomes occluded beyond the threshold
    public func whenOccluded(threshold: Double = 0.5) -> AnyPublisher<OcclusionResult, OcclusionError> {
        self.filter { $0.isOccluded(threshold: threshold) }
            .eraseToAnyPublisher()
    }

    /// Filters to only emit when the window becomes visible beyond the threshold
    public func whenVisible(threshold: Double = 0.5) -> AnyPublisher<OcclusionResult, OcclusionError> {
        self.filter { $0.isVisible(threshold: threshold) }
            .eraseToAnyPublisher()
    }

    /// Maps to coverage percentage only
    public func coverageOnly() -> AnyPublisher<Double, OcclusionError> {
        self.map(\.coveragePercentage)
            .eraseToAnyPublisher()
    }

    /// Maps to visibility percentage only
    public func visibilityOnly() -> AnyPublisher<Double, OcclusionError> {
        self.map(\.visiblePercentage)
            .eraseToAnyPublisher()
    }
}
