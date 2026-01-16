import XCTest
@testable import OcclusionKit

final class WindowQueryTests: XCTestCase {
    var mockProvider: MockWindowProvider!
    var calculator: OcclusionCalculator!

    override func setUp() {
        super.setUp()
        mockProvider = MockWindowProvider()
        calculator = OcclusionCalculator(provider: mockProvider)
    }

    // MARK: - Helper

    func makeWindow(
        id: CGWindowID,
        processID: pid_t = 1,
        bundleIdentifier: String? = "com.test.app",
        title: String? = nil,
        ownerName: String = "TestApp",
        frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
        zIndex: Int = 0
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            processID: processID,
            bundleIdentifier: bundleIdentifier,
            title: title,
            ownerName: ownerName,
            frame: frame,
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            zIndex: zIndex
        )
    }

    // MARK: - WindowMatcher Tests

    func testMatcherProcess() {
        let matcher = WindowMatcher.process(123)
        let window1 = makeWindow(id: 1, processID: 123)
        let window2 = makeWindow(id: 2, processID: 456)

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertFalse(matcher.matches(window2))
    }

    func testMatcherBundle() {
        let matcher = WindowMatcher.bundle("com.apple.Terminal")
        let window1 = makeWindow(id: 1, bundleIdentifier: "com.apple.Terminal")
        let window2 = makeWindow(id: 2, bundleIdentifier: "com.apple.Safari")

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertFalse(matcher.matches(window2))
    }

    func testMatcherBundlePattern() {
        let matcher = WindowMatcher.bundleMatching("com.apple.*")
        let window1 = makeWindow(id: 1, bundleIdentifier: "com.apple.Terminal")
        let window2 = makeWindow(id: 2, bundleIdentifier: "com.google.Chrome")

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertFalse(matcher.matches(window2))
    }

    func testMatcherTitle() {
        let matcher = WindowMatcher.title("My Window")
        let window1 = makeWindow(id: 1, title: "My Window")
        let window2 = makeWindow(id: 2, title: "Other Window")

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertFalse(matcher.matches(window2))
    }

    func testMatcherTitleContains() {
        let matcher = WindowMatcher.titleContains("Claude")
        let window1 = makeWindow(id: 1, title: "Claude - Chat")
        let window2 = makeWindow(id: 2, title: "Terminal")

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertFalse(matcher.matches(window2))
    }

    func testMatcherTitleContainsCaseInsensitive() {
        let matcher = WindowMatcher.titleContains("claude")
        let window = makeWindow(id: 1, title: "Claude - Chat")

        XCTAssertTrue(matcher.matches(window))
    }

    func testMatcherMinArea() {
        let matcher = WindowMatcher.minArea(5000)
        let bigWindow = makeWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)) // 10000
        let smallWindow = makeWindow(id: 2, frame: CGRect(x: 0, y: 0, width: 50, height: 50)) // 2500

        XCTAssertTrue(matcher.matches(bigWindow))
        XCTAssertFalse(matcher.matches(smallWindow))
    }

    func testMatcherAnd() {
        let matcher = WindowMatcher.bundle("com.test.app").and(.minArea(5000))
        let matching = makeWindow(id: 1, bundleIdentifier: "com.test.app", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let wrongBundle = makeWindow(id: 2, bundleIdentifier: "com.other.app", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let tooSmall = makeWindow(id: 3, bundleIdentifier: "com.test.app", frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        XCTAssertTrue(matcher.matches(matching))
        XCTAssertFalse(matcher.matches(wrongBundle))
        XCTAssertFalse(matcher.matches(tooSmall))
    }

    func testMatcherOr() {
        let matcher = WindowMatcher.bundle("com.test.app").or(.bundle("com.other.app"))
        let window1 = makeWindow(id: 1, bundleIdentifier: "com.test.app")
        let window2 = makeWindow(id: 2, bundleIdentifier: "com.other.app")
        let window3 = makeWindow(id: 3, bundleIdentifier: "com.third.app")

        XCTAssertTrue(matcher.matches(window1))
        XCTAssertTrue(matcher.matches(window2))
        XCTAssertFalse(matcher.matches(window3))
    }

    func testMatcherNot() {
        let matcher = WindowMatcher.bundle("com.test.app").not
        let window1 = makeWindow(id: 1, bundleIdentifier: "com.test.app")
        let window2 = makeWindow(id: 2, bundleIdentifier: "com.other.app")

        XCTAssertFalse(matcher.matches(window1))
        XCTAssertTrue(matcher.matches(window2))
    }

    // MARK: - WindowQuery Tests

    func testQueryByBundle() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1, bundleIdentifier: "com.apple.Terminal"),
            makeWindow(id: 2, bundleIdentifier: "com.apple.Safari"),
            makeWindow(id: 3, bundleIdentifier: "com.apple.Terminal")
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let windows = try await query.bundle("com.apple.Terminal").windows()

        XCTAssertEqual(windows.count, 2)
        XCTAssertTrue(windows.allSatisfy { $0.bundleIdentifier == "com.apple.Terminal" })
    }

    func testQueryByTitleContains() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1, title: "Claude - Chat"),
            makeWindow(id: 2, title: "Terminal"),
            makeWindow(id: 3, title: "Claude - Code")
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let windows = try await query.titleContains("Claude").windows()

        XCTAssertEqual(windows.count, 2)
    }

    func testQueryChaining() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1, processID: 100, title: "Big", frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            makeWindow(id: 2, processID: 100, title: "Small", frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            makeWindow(id: 3, processID: 200, title: "Big", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let windows = try await query.process(100).minArea(1000).windows()

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.id, 1)
    }

    func testQueryFirst() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1, title: "First", zIndex: 0),
            makeWindow(id: 2, title: "Second", zIndex: 1)
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let result = try await query.first()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.targetWindow.id, 1)
    }

    func testQueryFirstNone() async throws {
        mockProvider.mockWindows = []

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let result = try await query.first()

        XCTAssertNil(result)
    }

    func testQueryCount() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1),
            makeWindow(id: 2),
            makeWindow(id: 3)
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let count = try await query.count()

        XCTAssertEqual(count, 3)
    }

    func testQueryExists() async throws {
        mockProvider.mockWindows = [makeWindow(id: 1)]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)

        let exists = try await query.exists()
        let notExists = try await query.bundle("com.nonexistent.app").exists()

        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }

    func testQueryCustomFilter() async throws {
        mockProvider.mockWindows = [
            makeWindow(id: 1, ownerName: "App1"),
            makeWindow(id: 2, ownerName: "App2"),
            makeWindow(id: 3, ownerName: "App1")
        ]

        let query = WindowQuery(provider: mockProvider, calculator: calculator)
        let windows = try await query.filter { $0.ownerName == "App1" }.windows()

        XCTAssertEqual(windows.count, 2)
    }
}
